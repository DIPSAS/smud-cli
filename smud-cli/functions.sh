#!/usr/bin/env bash

show_valid_commands() 
{
    echo "Commands:"
    echo "  update-cli    Download and update the smud CLI. Required ${bold}curl${normal} installed on the computer" 
    echo "  version       Show the version of smud CLI" 
    echo "  list          List products ready for installation or current products installed."

    if [ ! $is_smud_dev_repo ]; then
        echo "  apply         Apply one or more productst to the repository."
        echo "  set-upstream  Set upstream https://github.com/DIPSAS/DIPS-GitOps-Template.git"
        echo "  upstream      Fetch upstream/main"
    else
        printf "${gray}Unavaible commands:${normal}\n"
        printf "  ${gray}apply         Apply one or more productst to the repository.${normal}\n"
        printf "  ${gray}set-upstream  Set upstream https://github.com/DIPSAS/DIPS-GitOps-Template.git${normal}\n"
        printf "  ${gray}upstream      Fetch upstream/main${normal}\n"
    fi

}

help()
{
    changes=(`cat $(dirname "$0")/CHANGELOG.md |sed -e 's/## Version /\n/g'`)

    # Print information
    echo "${bold}smud${normal}: Help dealing with products in the GitOps repository."
    echo "      Version "${changes[0]}""
    echo ""

    show_valid_commands

    echo "Usage:"
    echo "  smud <command> [options]"
}

show_invalid_command()
{
    printf "${red}Invalid command '$command'! ${normal}"
    echo ""
    echo "Please use:"
    show_valid_commands
}

version()
{
    changes=(`cat $(dirname "$0")/CHANGELOG.md |sed -e 's/## Version /\n/g'`)
    printf "${bold}smud version${normal}: Show the version of smud CLI\n" 
    echo "Current Version "${changes[0]}""
    echo ""
    echo "Changelog:"
    cat $(dirname "$0")/CHANGELOG.md| sed -e 's/## //g'
    echo ""
}

set_upstream()
{

    if [ $help ]; then
        echo "${bold}smud set-upstream${normal}: Set upstream https://github.com/DIPSAS/DIPS-GitOps-Template.git"
        return
    fi
    remote_upstream=$(git config --get remote.upstream.url)
    if [ ! $remote_upstream ]; then
        remote_upstream="https://github.com/DIPSAS/DIPS-GitOps-Template.git"
        git remote add upstream $remote_upstream
        printf "${gray}Upstream configured with '$remote_upstream' ${normal}\n"
    else
        printf "${gray}Upstream alredy configured with '$remote_upstream' ${normal}\n"
    fi
}

upstream()
{

    if [ $help ]; then
        echo "${bold}smud upstream${normal}: Fetch upstream"
        return
    fi
    remote_upstream=$(git config --get remote.upstream.url)
    if [ ! $remote_upstream ]; then
        set_upstream
    fi
    git fetch upstream
}

update_cli()
{
    if [ $help ]; then
        printf "${bold}smud update-cli${normal}: Download and update the smud CLI.\n"
        printf "                 Required ${bold}curl${normal} installed on the computer.\n"
        echo ""
        echo "> Download from https://api.github.com/repos/DIPSAS/smud-cli/contents/smud-cli"    
        echo "> Copy downloaded content to ~/smud-cli folder"    
        echo "> Prepare ~/.bashrc to load ~/smud-cli/.bash_aliases"    
        return
    fi

    printf "${bold}smud update-cli${normal}: Download and update the smud CLI.\n"
    echo ""

    . $(dirname "$0")/download-and-install-cli.sh $(basename "$0")
}
