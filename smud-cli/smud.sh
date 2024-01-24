#!/usr/bin/env bash
. $(dirname "$0")/install-cli.sh
. $(dirname "$0")/include.sh "$@"
. $(dirname "$0")/functions.sh
. $(dirname "$0")/functions-list.sh
. $(dirname "$0")/functions-upgrade.sh
. $(dirname "$0")/functions-init.sh

command=$1

print_verbose "\n${bold}command: $command\n" 


if [ ! $command ] ; then
    help
else
    case $command in 
        "--help"        ) help;;
        "version"       ) version;;
        "set-upstream"  ) set_upstream;;
        "init"          ) init $@;;
        "update-cli"    ) update_cli;;
        "list"          ) list;;
        "upgrade"       ) upgrade;;
        *               ) show_invalid_command;;

    esac    
fi
