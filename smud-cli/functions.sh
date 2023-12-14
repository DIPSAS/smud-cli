#!/usr/bin/env bash

default_upstream="https://github.com/DIPSAS/DIPS-GitOps-Template.git"


show_valid_commands() 
{
    echo "Commands:"
    echo "  update-cli    Download and update the smud CLI. Required ${bold}curl${normal} installed on the computer" 
    echo "  version       Show the version-log of smud CLI" 
    echo "  list          List products ready for installation or current products installed."

    if [ ! $is_smud_dev_repo ]; then
        echo "  apply         Apply one or more productst to the repository."
        echo "  set-upstream  Set upstream. If not specfied upstream-url, the https://github.com/DIPSAS/DIPS-GitOps-Template.git will be configured."
        echo "  upstream      Fetch upstream. If upstream-url is not set, the https://github.com/DIPSAS/DIPS-GitOps-Template.git will be configured before upstream is fetched."
        echo "  init          Same as upstream"
        echo ""
        echo "More help:"
        echo " > smud version"
        echo " > smud set-upstream --help"
        echo " > smud init --help"
        echo "   smud upstream --help"
        echo " > smud list --help"
        echo " > smud apply --help"
        echo " > smud list --examples"
    else
        printf "${gray}Unavaible commands:${normal}\n"
        printf "  ${gray}apply         Apply one or more productst to the repository.${normal}\n"
        printf "  ${gray}set-upstream  Set upstream. If not specfied upstream-url, the https://github.com/DIPSAS/DIPS-GitOps-Template.git will be configured.\n"
        printf "  ${gray}upstream      Fetch upstream. If upstream-url is not set, the https://github.com/DIPSAS/DIPS-GitOps-Template.git will be configured before upstream is fetched. ${normal}\n"
        printf "  ${gray}init          Same as upstream${normal}\n"
    fi

}

help()
{
    file="$(get_changelog_file)"
    if [ $file ]; then
        changes=(`cat $file |sed -e 's/## Version /\n/g'`)
        version="${changes[0]}"
    fi

    # Print information
    echo "${bold}smud${normal}: Help dealing with products in the GitOps repository."
    if [ $version ]; then
        echo "      Version "$version""
        echo ""
    fi

    show_valid_commands

    echo ""
    echo "Usage:"
    echo "  smud <command> [options]    - runs the smud <command> with [options]"
    echo "  smud <command> --debug      - run with debug-option"
    echo "  smud <command> --verbose    - run with verbose-option" 
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
    file="$(get_changelog_file)"

    if [ $file ]; then
        changes=(`cat $file |sed -e 's/## Version /\n/g'`)
        printf "${bold}smud version${normal}: Show the version of smud CLI\n" 
        echo "Current Version "${changes[0]}""
        echo ""
        echo "Changelog:"
        cat $file| sed -e 's/## //g'
        echo ""
    else
        echo "Changelog:"
        echo "  No CHANGELOG.md found"
    fi
}

set_upstream()
{
    caller=$1
    if [ $help ]; then
        echo "${bold}smud set-upstream${normal}: Set upstream"
        printf "With Only ${green}set-upstream${normal}, Upstream '$default_upstream' will be configured if not configured yet. \n"
        printf "With ${green}set-upstream ${bold}<value>${normal}, Upstream '<value>' will be configured. \n"
        printf "With ${green}set-upstream ${bold}-${normal}, Upstream will be removed. \n"
        return
    fi

    if [ ! "$is_repo" ]; then
        printf "${red}'$(pwd)' is not a git repository! ${normal}\n"
        return
    fi

    i=0
    new_value="${arg[0]}"
    while [[ "$new_value" == "--"* ]]; do
        i=$((i+1))
        new_value="${arg[$i]}"
    done
    # echo "new_value: $new_value"

    remote_upstream=$(git config --get remote.upstream.url)
    if [ $new_value ]; then
        remote_upstream=$new_value
        if [ $remote_upstream ]; then
            git remote rm upstream > /dev/null 2>&1
        fi    
        if [ "$remote_upstream" = "-" ]; then
            printf "${gray}Upstream is removed${normal}\n"
            exit
        else
            git remote add upstream $remote_upstream > /dev/null 2>&1
            printf "${gray}Upstream configured with '$remote_upstream' ${normal}\n"
        fi
    elif [ ! $remote_upstream ]; then
        remote_upstream=$default_upstream
        git remote add upstream $remote_upstream > /dev/null 2>&1
        printf "${gray}Upstream configured with '$remote_upstream' ${normal}\n"
    elif [ ! "$caller" ]; then
        printf "${gray}Upstream alredy configured with '$remote_upstream' ${normal}\n"
    fi
}

upstream()
{
    if [ $help ]; then
        func=${1:-init}
        echo "${bold}smud $func${normal}: Fetch upstream"
        printf "With Only ${green}$func${normal}, Upstream '$default_upstream' will be configured if not configured yet. When configured the upstream will be fetched. \n"
        printf "With ${green}$func ${bold}<value>${normal}, Upstream '<value>' will be configured before upstream is fetched. \n"
        printf "With ${green}$func ${bold}-${normal}, Upstream will be removed. \n"
        return
    fi

    if [ ! "$is_repo" ]; then
        printf "${red}'$(pwd)' is not a git repository! ${normal}\n"
        return
    fi

    set_upstream "upstream"

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


show_date_help()
{
    s=$1
    echo "      A specific date:"
    echo "        --$s='<DD.MM.YYYY HH:MM:SS +TZ>'"
    echo "        --$s='13.11.2023 08:00:00 +0000'"
    echo "      or relative dates:"
    echo "        --$s=today|tomorrow|yesterday"
    echo "        --$s='1 week ago|5 days ago|1 year ago'"
    
}