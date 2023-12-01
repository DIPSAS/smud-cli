# smud-cli

The `smud` CLI will make maintanance of your fork of DIPS' GitOps repository easier by providing simple commands for the most common tasks, such as:
- Listing the versions wich products are installed in which environments in which versions.
- Upgrading a set products at a time.

Requirements:
* linux computer or WSL
* curl installed on the computer 

## First time installation of `smud` CLI on the computer 


### Simple installation (recommended)
1. Open powershell or bash console
2. Run the command:
   ```shell
   bash -c "curl --ssl-no-revoke -H Accept:application/vnd.github.v3.raw https://api.github.com/repos/DIPSAS/smud-cli/contents/smud-cli/download-and-install-cli.sh --no-progress-meter | bash"
   ``` 


### Manual Download and install
1. Download the latest release [releases/Latest/download-and-install-cli.sh](https://github.com/DIPSAS/smud-cli/releases/download/Latest/download-and-install-cli.sh)
2. Open powershell or bash console
3. Run the command(s):
   ```shell
   cd [Downloaded-folder]
   bash -c ". ./download-and-install-cli.sh; rm ./download-and-install-cli.sh"
   ``` 

### Install information
> This will install the tool to the `~/smud-cli`-folder.  
> The `~.bashrc`-file will be updated with `~/smud-cli/.bash_aliases`

## Update the `smud` CLI 
When the `smud` CLI already is installed on the computer, run the following command to update it:
```sh
smud update-cli
```

## Using the `smud` CLI

Use the `--help` for investigating commands and options available:
```sh
smud --help
```
