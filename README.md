# ComputerCraft Package Manager (CCPM)

CCPM is a free and open-source package manager for ComputerCraft written in Lua. It is designed to simplify the distribution of packages by
providing tools to host and manage repositories.

A package manager or package management system is a collection of software tools that automates the process of
installing, upgrading, configuring, and removing computer programs for a computer in a consistent manner. (source:
[Wikipedia](https://en.wikipedia.org/wiki/Package_manager))

***

### Easy to use Command-Line Interface (CLI)

CCPM features a user-friendly CLI interface with autocompletion, inspired by Linux distributions package managers (such
as `dnf` or `apt`).

### Advanced dependency management

Repositories and packages both can have dependencies (which are referred as `companions` when talking about
repositories). CCPM will ensure that the dependency tree is coherent at any time with its transactional system.

If there is an error in the transaction, CCPM will automatically roll back the changes.

### Multiple repositories support

CCPM is designed to allow anyone to host their own repository directly on GitHub
(see [Host a CCPM Repository](#host-a-ccpm-repository)).

The base package `ccpm` is hosted in this repository, within the `Official CCPM repository`. If you think that
your package is an essential, you can submit it by opening a pull request against the `main` branch (see
[Submit a package to the `Official CCPM repository`](#submit-a-package-to-the-official-ccpm-repository)).

### Complete and documented API

The `ccpm` base package provides an easy-to-use API to integrate CCPM in your programs. For example, you can use CCPM as
the base for your ComputerCraft OS installer.

## Host a CCPM Repository

Hosting your CCPM repository is the recommended method because it allows **you** to use *GitHub Actions* to automatically
rebuild your repository index and **the users of your repository** to verify what they are downloading. In addition, CCPM
will simplify the usage of GitHub-hosted repository by automatically figuring out the repository URL.

### With GitHub (recommended)

When using GitHub, your repository will be identified by its GitHub identifier (*GitHub username*/*repository name*).
For instance, this repository (the `Official CCPM repository`) can be installed with the CCPM command
`ccpm register Deleranax/ccpm`.

1. Install the Python package `ccpm-tools` which contains tools to simplify the deployment of new CCPM
repositories (requires Python >= 3.12).
    ```bash
    pip install ccpm-tools
    ccpm-tools
    ```

2. Create a new repository on GitHub. The naming convention for CCPM repository/packages is the *kebab-case* (all lower
case with hyphens).

3. Clone your repository.
   ```bash
   git clone https://github.com/me/my-repository.git
   ```

4. Set up the CCPM repository. The name specified in the command is just a display name, which means that you are not
required to comply with the naming conventions. You can add maintainers with `-m` and companion repositories with
`-c`.
   ```bash
   ccpm-tools init "My repository" -m "Maintainer" -c "me/my-other-repository"
   ``` 
> [!NOTE]
> The effective name of a GitHub-hosted CCPM repository is *GitHub username*/*repository name*. The "name" as specified
> in the manifest will only be used when the repository is hosted outside GitHub.

> [!TIP]
> Companions are repositories that contain dependencies for this repository. They will be installed along with
> repository when installed by the user. To add a repository as a companion, use de `-c` argument with the identifier of
> the repository.

5. *(Optional)* Set up GitHub Action to automatically rebuild the package index on every push. Create a file named
`deploy.yml` in the directory `.github/workflows` at the root of your repository. Copy the content of the
[GitHub action used on this repository](https://github.com/Deleranax/ccpm/blob/main/.github/workflows/deploy.yml).

6. Create a package. See [Publish a package](#publish-a-package).

7. Update the repository index. When you modify something in the repository (a package file, a package manifest, or the
repository manifest), you need to rebuild the package index. **You can skip this step if you did the optional step 5**.
   ```bash 
   ccpm-tools build
   ```

8. Commit and push to GitHub.
   ```bash
   git commit -am "Added packages"
   git push
   ```

9. Enjoy! You can install the repository using `ccpm register *GitHub username*/*repository name*`.

### With any HTTPS-capable static file serving service

When not using GitHub, your repository will be identified by its URL (e.g., `https://example.com/example`). The
convention is to use a simple URL without any trailing `/`.

> [!CAUTION]
> CCPM does not enforce the unicity of the URL, which means that if the URLs `https://example.com/example` and
> `https://example.example.com/` are considered as two different repositories even if they point to the same manifest.
> Be careful to distribute it using the same URL format to all the users.

1. Install the Python package `ccpm-tools` which contains tools to simplify the deployment of new CCPM
repositories (requires Python >= 3.12). You can install it on your local machine or directly on your server.
    ```bash
    pip install ccpm-tools
    ccpm-tools
    ```

2. Set up the CCPM repository. The name specified in the command is just a display name, which means that you are not
required to comply with the naming conventions. You can add maintainers with `-m` and companion repositories with
`-c`.
   ```bash
   ccpm-tools init "My repository" -m "Maintainer" -c "me/my-other-repository"
   ```
   
> [!TIP]
> Companions are repositories that contain dependencies for this repository. They will be added along with the
> repository when added by the user. To add a repository as a companion, use de `-c` argument with the identifier of
> the repository.

3. Create a package. See [Publish a package](#publish-a-package).

4. Update the repository index. When you modify something in the repository (a package file, a package manifest, or the
repository manifest), you need to rebuild the package index.
   ```bash 
   ccpm-tools build
   ```
5. Upload/statically serve the directory in which you executed the commands.

6. Enjoy! You can install the repository using `ccpm register *URL*`.

## Publish a package

The following instructions describe the procedure to compose a valid `ccpm` package to add it to a CCPM repository, or
submit a package to the `Official CCPM repository`.

### Regular package

(TODO)

### Meta package

(TODO)

## Submit a package to the `Official CCPM repository`

(TODO)