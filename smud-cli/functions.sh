#!/usr/bin/env bash

print_verbose "**** START: functions.sh"

show_valid_commands() 
{
    echo "Commands:"
    echo "  update-cli    Download and update the smud CLI. Required ${bold}curl${normal} installed on the computer" 
    echo "  version       Show the version-log of smud CLI" 
    echo "  list          List products ready for installation or current products installed."
    echo "  conflict(s)   Scan and list conflicts in yaml-files."

    if [ ! "$is_smud_dev_repo" ]; then
        echo "  upgrade       Upgrade one or more productst to the repository."
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
        echo " > smud upgrade --help"
        echo " > smud list --examples"
    else
        printf "${gray}Unavaible commands:${normal}\n"
        printf "  ${gray}upgrade       Upgrade one or more productst to the repository.${normal}\n"
        printf "  ${gray}set-upstream  Set upstream. If not specfied upstream-url, the https://github.com/DIPSAS/DIPS-GitOps-Template.git will be configured.\n"
        printf "  ${gray}upstream      Fetch upstream. If upstream-url is not set, the https://github.com/DIPSAS/DIPS-GitOps-Template.git will be configured before upstream is fetched. ${normal}\n"
        printf "  ${gray}init          Same as upstream${normal}\n"
    fi

}

get_changelog_file()
{
    BASEDIR="$(dirname "$0")"
    file="$BASEDIR/CHANGELOG.md"

    if [ ! -f $file ]; then
        BASEDIR="$(dirname "$BASEDIR")"
        file="$BASEDIR/CHANGELOG.md"
    fi
    if [ -f $file ]; then
        echo "$file"    
    fi
}

help()
{
    version="$(changelog_get_version)"

    # Print information
    echo "${bold}smud${normal}: Help dealing with products in the GitOps repository."
    if [ "$version" ]; then
        echo "      Version $version"
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

changelog_get_version() 
{
    file=$1    
    if [ ! "$file" ]; then
        file="$(get_changelog_file)"
    fi
    if [ "$file" ]; then
        old_SEP=$IFS
        IFS='#'
        changes=(`cat $file`)
        version="$(echo "${changes[2]}"|sed -e 's/ Version //g'| cut -d "-" -f 1 | tr -d '\n' )"
        IFS=$old_SEP
    fi
    echo $version
}

version()
{
    file="$(get_changelog_file)"

    if [ "$file" ]; then
        changes=(`cat $file |sed -e 's/## Version /\n/g'`)
        printf "${bold}smud version${normal}: Show the version of smud CLI\n" 
        echo "Current Version "$(changelog_get_version)""
        echo ""
        echo "Changelog:"
        cat $file| sed -e 's/## //g'
        echo ""
    else
        echo "Changelog:"
        echo "  No CHANGELOG.md found"
    fi
}

update_cli()
{
    if [ "$help" ]; then
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
    s="$1"
    echo "      A specific date:"
    echo "        --$s='<DD.MM.YYYY HH:MM:SS +TZ>'"
    echo "        --$s='13.11.2023 08:00:00 +0000'"
    echo "      or relative dates:"
    echo "        --$s=today|tomorrow|yesterday"
    echo "        --$s='1 week ago|5 days ago|1 year ago'"
}

print_verbose "**** END: functions.sh"