#!/usr/bin/env bash
. $(dirname "$0")/install-cli.sh
. $(dirname "$0")/include.sh "$@"
. $(dirname "$0")/functions.sh
. $(dirname "$0")/functions-list.sh
. $(dirname "$0")/functions-apply.sh

command=$1

if [ $verbose ]; then
      echo "command: $command" 
fi


if [ ! $command ] ; then
    help
else
    case $command in 
        "--help"        ) help;;
        "version"       ) version;;
        "set-upstream"  ) set_upstream;;
        "upstream"      ) upstream;;
        "update-cli"    ) update_cli;;
        "list"          ) list;;
        "apply"         ) apply;;
        *               ) show_invalid_command;;

    esac    
fi
