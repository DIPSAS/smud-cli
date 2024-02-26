print_verbose "**** START: functions-conflicts.sh"

conflicts()
{
    if [ "$help" ]; then
        echo "${bold}smud conflict(s)${normal}: Scan and list conflicts in yaml-files."
        return
    fi
    if [ ! "$is_repo" ]; then
        printf "${red}'$(pwd)' is not a git repository! ${normal}\n"
        return
    fi
    printf "${white}Scan and list conflicts in yaml-files.\n"
    
    sh -c "find $find_files_filter -name '*.yaml' -exec grep -H -e '>>>' -e '<<<' {} \;"
}

print_verbose "**** END: functions-conflicts.sh"