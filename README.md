# smud-cli

The `smud` CLI will make maintanance of your fork of DIPS' GitOps repository easier by providing simple commands for the most common tasks, such as:
- Listing the versions wich products are installed in which environments in which versions.
- Upgrading a set products at a time.

Requirements:
* linux computer or WSL
* curl installed on the computer 

## First time installation of `smud` CLI on the computer 

### Download
You can download the installation-file from the browser:  
[DIPSAS/smud-cli/main/smud-cli/download-and-install-cli.sh](https://raw.githubusercontent.com/DIPSAS/smud-cli/main/smud-cli/download-and-install-cli.sh?token=GHSAT0AAAAAACKWMYRR6QHMHCVDJ4U4MVQ2ZK7YO7Q)

Or, you can download the installation-file by running the following command from the linux bash console: 
```sh
curl --ssl-no-revoke https://raw.githubusercontent.com/DIPSAS/smud-cli/main/smud-cli/download-and-install-cli.sh?token=GHSAT0AAAAAACKWMYRR6QHMHCVDJ4U4MVQ2ZK7YO7Q -o download-and-install-cli.sh
```


### Installation
Run the installation-file by running the following command from the linux bash console

```sh
. ./download-and-install-cli.sh; rm ./download-and-install-cli.sh
```

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
