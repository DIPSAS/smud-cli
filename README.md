# smud-cli

The `smud` CLI will make maintanance of your fork of DIPS' GitOps repository easier by providing simple commands for the most common tasks, such as:
- Listing the versions wich products are installed in which environments in which versions.
- Upgrading a set products at a time.

Requirements:
* linux computer or WSL
* curl installed on the computer 

## First time installation of `smud` CLI on the computer 

### Download
You can download the installation-file from the browser (Require login to github.com):  
1. Open [DIPSAS/smud-cli/main/smud-cli/download-and-install-cli.sh](https://github.com/DIPSAS/smud-cli/blob/main/smud-cli/download-and-install-cli.sh)
2. Dowload file by pushing the "Download raw file" button (<svg aria-hidden="true" focusable="false" role="img" class="octicon octicon-download" viewBox="0 0 16 16" width="16" height="16" fill="currentColor" style="display:inline-block;user-select:none;vertical-align:text-bottom;overflow:visible"><path d="M2.75 14A1.75 1.75 0 0 1 1 12.25v-2.5a.75.75 0 0 1 1.5 0v2.5c0 .138.112.25.25.25h10.5a.25.25 0 0 0 .25-.25v-2.5a.75.75 0 0 1 1.5 0v2.5A1.75 1.75 0 0 1 13.25 14Z"></path><path d="M7.25 7.689V2a.75.75 0 0 1 1.5 0v5.689l1.97-1.969a.749.749 0 1 1 1.06 1.06l-3.25 3.25a.749.749 0 0 1-1.06 0L4.22 6.78a.749.749 0 1 1 1.06-1.06l1.97 1.969Z"></path></svg>)

Or, you can download the installation-file by running the following command from the linux bash console: 
```sh
curl --ssl-no-revoke -H "Accept: application/vnd.github.v3.raw" -H "Authorization: token $(echo "WjJod1gxTjZkekZIWVdaVVkwUm9iVk5VYzAxWFdFcE5PR2RSU2xGSlozQlpSekprUlZkdVF3PT0=" | base64 --decode | base64 --decode)"  https://api.github.com/repos/DIPSAS/smud-cli/contents/smud-cli/download-and-install-cli.sh --no-progress-meter -o  download-and-install-cli.sh
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
