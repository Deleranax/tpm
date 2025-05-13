# ComputerCraft Temver Package Manager (CC-TPM)

CC-TPM is a package manager for ComputerCraft written in Lua. It is designed to simplify the distribution of packages by
providing tools to host and manage repositories.

A repository is a collection of packages, hosted on GitHub or any other service that offers static file serving. To host
your own repository, see [Host a TPM Repository](#host-a-tpm-repository).

The base package `tpm` is hosted in this repository, along with the `TPM default repository`. If you think that your
package is an essential, you can submit it by opening a pull request against the `main` branch (
see [Compose and submit a package](#publish-a-package)).

## Host a TPM Repository

Hosting your TPM repository is the recommended method because it allows **you** to use *GitHub Actions* to automatically
rebuild your repository index and **the users of your repository** to verify what they are downloading. In addition, TPM
will simplify the usage of GitHub-hosted repository by automatically figuring out the repository URL.

### With GitHub (recommended)

When using GitHub, your repository will be identified by its GitHub identifier (*GitHub username*/*repository name*).
For instance, this repository (the `TPM default repository`) can be installed with the TPM command
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

8. Enjoy! You can install the repository using `tpm repo add *GitHub username*/*repository name*`.

## Publish a package

The following instructions describe the procedure to compose a valid `tpm` package to add it to a TPM repository, or
submit a package to the `Default TPM Repository`. If the package is intended to be submitted to the
`Default TPM Repository`, some specific guidelines may apply (but these will be indicated each time).
