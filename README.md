# smud-cli

#### The `smud` CLI will help dealing with products in the GitOps repository.

Requirements:
* linux computer or WSL
* curl installed on the computer 

## First time installation of `smud` CLI on the computer 

### Download
You can download the installation-file from the browser:  
[DIPSAS/smud-cli/main/smud-cli/download-and-install-cli.sh](https://github.com/DIPSAS/smud-cli/blob/main/smud-cli/download-and-install-cli.sh)

Or, you can download the installation-file by running the following command from the linux bash console: 
```sh
#!/bin/bash
# PS! Does not work now. Need a better permanent download-link 
curl https://raw.githubusercontent.com/DIPSAS/smud-cli/main/smud-cli/download-and-install-cli.sh?token=GHSAT0AAAAAACKHKNOHNFNNBKYPYNNJCHZUZK2P74Q -o download-and-install-cli.sh
```


### Installation
Run the installation-file by running the following command from the linux bash console

```sh
#!/bin/bash

sh download-and-install-cli.sh # PS! Required that 'curl' is insalled on the machine
rm download-and-install-cli.sh
```

> This will install the tool to the `~/smud-cli`-folder.  
> The `~.bashrc`-file will be updated with `~/smud-cli/.bash_aliases`

## Update the `smud` CLI 
When the `smud` CLI already is installed on the computer, run the following command to update it:
```sh
#!/bin/bash

smud update-cli
```

## Using the `smud` CLI

Use the `--help` for investigating commands and options available:
```sh
#!/bin/bash

smud --help
```
