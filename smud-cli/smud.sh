#!/usr/bin/env bash
command="$1"

. $(dirname "$0")/smud-main.sh "$@"
print_verbose "**** START: smud.sh"
. $(dirname "$0")/install-cli.sh "$@"
. $(dirname "$0")/functions-init.sh
. $(dirname "$0")/functions.sh
. $(dirname "$0")/functions-conflicts.sh
. $(dirname "$0")/functions-list.sh
. $(dirname "$0")/functions-upgrade.sh
. $(dirname "$0")/functions-gitops.sh
. $(dirname "$0")/functions-resources.sh

print_verbose "\n${bold}command: $command\n" 

if [ ! "$command" ] ; then
    help
else
    case "$command" in 
        "--help"        ) help;;
        "version"       ) version;;
        "set-upstream"  ) set_upstream;;
        "init"          ) init "${3:-$2}";;
        "git"          ) init "${3:-$2}";;
        "update-cli"    ) update_cli;;
        "conflict"      ) conflicts;;
        "conflicts"     ) conflicts;;
        "resource"      ) resources;;
        "resources"     ) resources;;
        "ls"            ) list;;
        "list"          ) list;;
        "apply"         ) upgrade;;
        "upgrade"       ) upgrade;;
        *               ) show_invalid_command;;

    esac    
fi

print_verbose "**** END: smud.sh"