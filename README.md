# ComputerCraft Temver Package Manager (CC-TPM)

TPM is a free and open-source package manager for ComputerCraft written in Lua. It is designed to simplify the distribution of packages by
providing tools to host and manage repositories.

A package manager or package management system is a collection of software tools that automates the process of
installing, upgrading, configuring, and removing computer programs for a computer in a consistent manner. (source:
[Wikipedia](https://en.wikipedia.org/wiki/Package_manager))

***

### Easy to use Command-Line Interface (CLI)

TPM features a user-friendly CLI interface, inspired by Linux distributions package managers (such as `dnf` or `apt`). It
is 

### Advanced dependency management

Repositories and packages can have dependencies, which are resolved at installation. The dependency tree is optimized at
any time: TPM automatically removes unused dependencies (packages or repositories).

### Multiple repositories support

TPM is designed to allow anyone to host their own repository directly on GitHub
(see [Host a TPM Repository](#host-a-tpm-repository)).

The base package `tpm` is hosted in this repository, within the `Official default TPM repository`. If you think that
your package is an essential, you can submit it by opening a pull request against the `main` branch (see
[Submit a package to the `Official default TPM repository`](#submit-a-package-to-the-official-default-tpm-repository)).

### Complete and documented API

The `tpm` base package provides an easy-to-use API to integrate TPM in your programs. For example, you can use TPM as
the base for your ComputerCraft OS installer.

## Host a TPM Repository

Hosting your TPM repository is the recommended method because it allows **you** to use *GitHub Actions* to automatically
rebuild your repository index and **the users of your repository** to verify what they are downloading. In addition, TPM
will simplify the usage of GitHub-hosted repository by automatically figuring out the repository URL.

### With GitHub (recommended)

When using GitHub, your repository will be identified by its GitHub identifier (*GitHub username*/*repository name*).
For instance, this repository (the `Official default TPM repository`) can be installed with the TPM command
`tpm repo add Deleranax/tpm`.

1. Install the Python package `cc-tpm-tools` which contains tools to simplify the deployment of new TPM
repositories (requires Python >= 3.12).
    ```bash
    pip install cc-tpm-tools
    cctpm
    ```

2. Create a new repository on GitHub. The naming convention for TPM repository/packages is the *kebab-case* (all lower
case with hyphens).

3. Clone your repository.
   ```bash
   git clone https://github.com/me/my-repository.git
   ```

4. Set up the TPM repository. The name specified in the command is just a display name, which means that you are not
required to comply with the naming conventions. You can add maintainers with `-m` and companion repositories with
`-c`.
   ```bash
   cctpm init "My repository" -m "Maintainer" -c "me/my-other-repository"
   ``` 
> [!NOTE]
> The effective name of a GitHub-hosted TPM repository is *GitHub username*/*repository name*. The "name" as specified
> in the manifest will only be used when the repository is hosted outside GitHub.

> [!TIP]
> Companions are repositories that contain dependencies for this repository. They will be installed along with
> repository when installed by the user. To add a repository as a companion, use de `-c` argument with the identifier of
> the repository.

5. *(Optional)* Set up GitHub Action to automatically rebuild the package index on every push. Create a file named
`deploy.yml` in the directory `.github/workflows` at the root of your repository. Copy the content of the
[GitHub action used on this repository](https://github.com/Deleranax/tpm/blob/main/.github/workflows/deploy.yml).

6. Create a package. See [Publish a package](#publish-a-package).

7. Update the repository index. When you modify something in the repository (a package file, a package manifest or the
repository manifest), you need to rebuild the package index. **You can skip this step if you did the optional step 5**.
   ```bash 
   cctpm build
   ```

8. Commit and push to GitHub.
   ```bash
   git commit -am "Added packages"
   git push
   ```

9. Enjoy! You can install the repository using `tpm repo add *GitHub username*/*repository name*`.

### With any HTTPS-capable static file serving service

When not using GitHub, your repository will be identified by its URL (e.g., `https://example.com/example`). The
convention is to use a simple URL without any trailing `/`.

> [!CAUTION]
> TPM does not enforce the unicity of the URL, which means that if the URLs `https://example.com/example` and
> `https://example.example.com/` are considered as two different repositories even if they point to the same manifest.
> Be careful to distribute it using the same URL format to all the users.

1. Install the Python package `cc-tpm-tools` which contains tools to simplify the deployment of new TPM
repositories (requires Python >= 3.12). You can install it on your local machine or directly on your server.
    ```bash
    pip install cc-tpm-tools
    cctpm
    ```

2. Set up the TPM repository. The name specified in the command is just a display name, which means that you are not
required to comply with the naming conventions. You can add maintainers with `-m` and companion repositories with
`-c`.
   ```bash
   cctpm init "My repository" -m "Maintainer" -c "me/my-other-repository"
   ```
   
> [!TIP]
> Companions are repositories that contain dependencies for this repository. They will be installed along with
> repository when installed by the user. To add a repository as a companion, use de `-c` argument with the identifier of
> the repository.

3. Create a package. See [Publish a package](#publish-a-package).

4. Update the repository index. When you modify something in the repository (a package file, a package manifest or the
repository manifest), you need to rebuild the package index.
   ```bash 
   cctpm build
   ```
5. Upload/statically serve the directory in which you executed the commands.

6. Enjoy! You can install the repository using `tpm repo add *URL*`.

## Publish a package

The following instructions describe the procedure to compose a valid `tpm` package to add it to a TPM repository, or
submit a package to the `Official default TPM repository`.

### Regular package

(TODO)

### Meta package

(TODO)

## Submit a package to the `Official default TPM repository`

(TODO)