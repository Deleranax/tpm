# CCPM Repository Control Utility
# Copyright (C) 2025 Deleranax
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

import json
import re
import time
from hashlib import sha256
from pathlib import Path

import typer
from typing_extensions import List, Annotated

app = typer.Typer(rich_markup_mode=None, no_args_is_help=True)

@app.command()
def init(
        name: Annotated[str, typer.Argument(help="Name of the repository. Must contain only alphanumeric characters and dashes.")] = None,
        maintainers: Annotated[List[str], typer.Option("--maintainer", "-m", help="Add a maintainer to the repository.")] = [],
        companions: Annotated[List[str], typer.Option("--companion", "-c", help="Add a companions to the repository. Companions are repositories that contain dependencies for this repository.")] = [],
):
    """Initialize or modify the repository in the current directory."""
    if name is not None and not re.match(r"^[a-zA-Z0-9-]+$", name):
        print("Error: Repository name must contain only alphanumeric characters and dashes.")

    root = Path.cwd()

    # Load the repository if it exists
    if find_repository_root() is not None:
        root = get_repository_root()
        manifest = read_repository_manifest()

        if name is None:
            name = manifest["name"]
        maintainers = manifest["maintainers"] + maintainers
        companions = manifest["companions"] + companions
        print(f"Updated repository {name}.")
    else:
        if name is None:
            print("Error: Repository name is required when initializing a new repository.")
            raise typer.Exit(code=1)
        print(f"Created repository {name}.")

    pool = root / "pool"
    pool.mkdir(exist_ok=True)

    with open(root / "manifest.json", "w") as manifest_file:
        manifest = {"name": name, "maintainers": maintainers, "companions": companions}
        json.dump(manifest, manifest_file, indent=2)

@app.command()
def build():
    """Build the repository index. This command must be run after every change to the repository's content (e.g., packages manifests, packages files, ...)."""
    manifest = read_repository_manifest()
    root = get_repository_root()
    pool = root / "pool"
    pool.mkdir(exist_ok=True)

    index = {"timestamp": int(time.time()), **manifest, "packages": []}

    for package_dir in pool.glob("*"):
        if package_dir.is_dir():
            package_manifest_path = package_dir / "manifest.json"
            if package_manifest_path.exists():
                print(f"Updating package {package_dir.name}...")

                manifest = {}
                files = {}

                with open(package_manifest_path, "r") as manifest_file:
                    manifest = json.load(manifest_file)

                for file in package_dir.rglob("*"):
                    if file.is_file() and file.name != "manifest.json":
                        hash = sha256()
                        with open(file, "rb") as f:
                            hash.update(f.read())
                        file_hash = hash.hexdigest()
                        files[str(file.relative_to(package_dir))] = file_hash
                        print("- " + str(file.relative_to(package_dir)) + " (" + file_hash + ")")

                index["packages"].append({"name": package_dir.name, **manifest, "files": files})
            else:
                print(f"Warning: Package {package_dir.name} has no manifest.")
        else:
            print(f"Warning: Garbage at '{package_dir.name}'")

    with open(root / "index.json", "w") as index_file:
        json.dump(index, index_file, indent=2)

@app.command()
def package(
        name: Annotated[str, typer.Argument(help="Name of the package. Must contain only lower case alphanumeric characters and dashes.")],
        description: Annotated[str, typer.Option("--description", "-d", help="Description of the package.")] = "A CCPM package.",
        version: Annotated[str, typer.Option("--version", "-v", help="Version of the package.")] = "0.1.0",
        licence: Annotated[str, typer.Option("--licence", "-l", help="Licence of the package.")] = "GPL-2.0-or-later",
        author: Annotated[List[str], typer.Option("--author", "-a", help="Add an author to the package.")] = [],
        maintainer: Annotated[List[str], typer.Option("--maintainer", "-m", help="Add a maintainer to the package.")] = [],
        dependency: Annotated[List[str], typer.Option("--dependency", "-c", help="Add a dependency to the package.")] = [],
        force: Annotated[bool, typer.Option("--force", "-f", help="Overwrite an existing package.")] = False,
):
    """Create a new package in the repository."""
    root = get_repository_root()
    pool = root / "pool"
    pool.mkdir(exist_ok=True)
    package_dir = pool / name
    package_dir.mkdir(exist_ok=True)
    package_manifest_path = package_dir / "manifest.json"

    name = name.lower()
    if not re.match(r"^[a-z0-9-]+$", name):
        print("Error: Package name must contain only lower case alphanumeric characters and dashes.")

    package_manifest = {"description": description, "version": version, "licence": licence, "authors": author, "maintainers": maintainer, "dependencies": dependency}

    if not force and package_manifest_path.exists():
        print(f"Error: Package {name} already exists.")
        raise typer.Exit(code=1)
    else:
        with open(package_manifest_path, "w") as manifest_file:
            json.dump(package_manifest, manifest_file, indent=2)
        print(f"Created package {name}.")

@app.command(name="list")
def list_packages():
    """List all packages in the repository."""
    manifest = read_repository_manifest()
    packages = read_package_index()
    if len(packages["packages"]) == 0:
        print(f"Repository {manifest['name']} contains no packages.")
        return
    else:
        print(f"Repository {manifest["name"]} contains {len(packages["packages"])} packages:")
        for package in packages["packages"]:
            print(f"- {package["name"]} ({package['version']})")


def find_repository_root():
    cwd = Path.cwd()
    while True:
        manifest_path = cwd / "manifest.json"
        if manifest_path.exists():
            return cwd
        else:
            cwd = cwd.parent
            if cwd == cwd.parent:
                return None

def get_repository_root():
    root = find_repository_root()

    if root is not None:
        return root
    else:
        print("Error: Repository root not found. Are you in a repository directory?")
        raise typer.Exit(code=1)

def read_repository_manifest():
    root = get_repository_root()
    manifest_path = root / "manifest.json"

    if manifest_path.exists():
        with open(root / "manifest.json", "r") as manifest_file:
            manifest = json.load(manifest_file)
            return manifest
    else:
        print("Error: Repository manifest not found. Have you initialized the repository?")
        raise typer.Exit(code=1)

def read_package_index():
    root = get_repository_root()
    index_path = root / "index.json"

    if index_path.exists():
        with open(index_path, "r") as index_file:
            index = json.load(index_file)
        return index
    else:
        print("Error: Repository index not found. Have you built the repository? Try 'ccpm-tool build'.")
        raise typer.Exit(code=1)

if __name__ == "__main__":
    app()