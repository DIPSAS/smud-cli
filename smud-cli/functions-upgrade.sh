#!/usr/bin/env bash

upgrade()
{
    if [ "$debug" ] && [ "$git_grep" ]; then
        echo "git_grep: $git_grep"
    fi
    if [ $help ]; then
        echo "${bold}smud upgrade${normal} [options]: Upgrade one or more productst to the repository."
        echo ""
        echo "Options:"
        echo "  --product=, -P=:"
        echo "      Upgrade only the selected product."
        echo "  --from-commit=,-FC=:"
        echo "      Upgrade only products ${bold}from${normal} a specific commit"
        echo "  --to-commit=,-TC=:"
        echo "      Upgrade only products ${bold}to${normal} a specific commit"
        echo "  --from-date,-FD:"
        echo "      Upgrade only products ${bold}from${normal} a specific date"
        show_date_help "from-date"
        echo "  --to-date,-TD:"
        echo "      Upgrade only products ${bold}to${normal} a specific date"
        show_date_help "to-date"
        echo "  --version,-V:"
        echo "      Upgrade only products ${bold}with${normal} a specific version"
        echo "      -G'chartVersion: $version' | -S'chartVersion: $version'"
        echo "  --stage=, -S=:"
        echo "      Upgrade only products on selected stage."
        echo "  --external-test,-ET:"
        echo "      Upgrade only products on external-test stage. Override --stage parameter"
        echo "  --production,-PROD:"
        echo "      Upgrade only products on production stage. Override --stage parameter"
        echo "  --silent:"
        echo "      Upgrade without question."
        echo "  --remote, remote=<branch>:"
        echo "      Push to remote when all selected version was successfully applied."
        echo "      If --remote is used, the default-branch will be used"
        echo "  --undo=<commit>:"
        echo "      Undo all changes back to specific commit"
        echo "  --examples,-ex:"
        echo "      Show examples"
        if [ "$examples" ]; then 
            echo ""
            echo "Examples:"
            echo "  # Upgrade all audit-product commits on all stages"
            echo "  smud upgrade --product=audit --remote=main"
            echo ""
        fi
        return
    fi

    init

    if [ ! "$is_repo" ]; then
        print_error "'$(pwd)' is not a git repository!"
        return
    fi

    if [ ! "$git_range" ]; then
        print_error "No revisions available to upgrade!"
        return
    fi

    local context="products"
    local upgrade_filter=$filter
    local yes_no="y"
    if [ ! "$product" ]; then
        echo "No Products specified by [--products=, --product=, -P=] or [--all, -A]."
        if [ ! "$silent" ]; then
            ask yes_no $yellow "Do you want to upgrade the GitOps-model (Yes/No)?"
        fi
        if [ ! "$yes_no" = "yes" ]; then
            local upgrade_filter=$devops_model_filter
            local context="GitOps-model files"
            print_gray "Swithced to '$context' context"
        else
            return
        fi    
    fi
    has_changes_command="git log $git_range --max-count=1 --no-merges --pretty=format:1 -- $upgrade_filter"
    run_command --has-commits --command-var=has_changes_command --return-var='has_commits' --debug-title='Check if any changes' || return
    if [ ! "$has_commits" ]; then
        print_gray "No $context found."   
        return
    fi


    yes_no="yes"
    if [ ! $silent ]; then
      list
      ask yes_no $yellow "Do you want to continue upgrading the selected $context (Yes/No)? "
    fi  
    local upgrade_error_code=0
    if [ "$yes_no" = "yes" ] || [ "$yes_no" = "y" ]; then
        commits_command="git rev-list $from_commit^..$to_commit $date_range $git_grep --reverse --no-merges $diff_filter -- $upgrade_filter"
        run_command --commits --command-var=commits_command --return-var=rev_list --skip-error=true --error-code=upgrade_error_code --debug-title='Find commits to upgrade'
        
        if [ $upgrade_error_code -eq 128 ]; then
            commits_command="git rev-list $from_commit..$to_commit $date_range $git_grep --reverse --no-merges $diff_filter -- $upgrade_filter"
            run_command --commits --command-var=commits_command --return-var=rev_list --debug-title='Find commits to upgrade' || return
        fi

        if [ ! "$rev_list" ]; then
            print_gray "No $context found."   
            return
        fi
        IFS=$'\n';read -rd '' -a rev_list <<< "$rev_list"
        commits="${rev_list[@]}"
        print_gray "Running: git cherry-pick [commits]...\n"   
        print_debug "$commits"
        # If there are any current unapplied changes, cherry pick will fail. Catch this.
        cherrypick_commits_command="git cherry-pick $commits"
        run_command cherry-pick --command-var=cherrypick_commits_command --return-var=log --debug-title='Start cherry-pick' || error_message=$log

        # Check if cherry-pick in progress
        error_index="$(echo "$error_message" | grep "cherry-pick is already in progress" -c)"
        if [ $error_index -gt 0 ]; then
            error_message=""
            cherrypick_commits_command="git cherry-pick --continue"
            run_command cherry-pick --command-var=cherrypick_commits_command --return-var=log --debug-title='Continue cherry-pick' || error_message=$log
        fi

        # Check if cherry-pick was resolved
        error_index="$(echo "$error_message" | grep "The previous cherry-pick is now empty, possibly due to conflict resolution" -c)"
        if [ $error_index -gt 0 ]; then
            error_message=""
            cherrypick_commits_command="git cherry-pick --skip"
            run_command cherry-pick --command-var=cherrypick_commits_command --return-var=log --debug-title='Skip cherry-pick' || error_message=$log
        fi

        # Loop until no conflicts
        # Print status in plain text after each file listing
        # If the conflict is UD (delete happened in remote) resolve it automatically using "merge-strategy theirs"
        if [ -n "$error_message" ]; then
            errors_resolved="false"
            printf "${red}Cherry-pick ran into errors that must be resolved manually.\n${normal}"
            #echo "$error_message"
            while [ "$errors_resolved" == "false" ]; do 
                files_status=$(git status -s)

                declare -A status_map

                while IFS= read -r line; do
                    # Extract the file status
                    status_code=$(echo "$line" | cut -c -2)
                    # Extract the file name
                    file=$(echo "$line" | cut -c 4-)
                    # Add the file to the map where the status is the key
                     if [[ -n "${status_map["$status_code"]}" ]]; then
                        # If it exists, append the current file to the existing array
                        status_map["$status_code"]+=" $file"
                    else
                        # If it doesn't exist, create a new array with the current file
                        status_map["$status_code"]=$file
                    fi
                done < <(git status -s)

                merge_conflict_status_codes="DD AU UD UA DU AA UU"
                untracked_status_code="??"

                printf "${red}The follwing contains changes that must be resolved:\n${normal}" 
                for status_code in "${!status_map[@]}"; do
                    filenames="${status_map[$status_code]}"
                    description=$(get_status_description "$status_code")
                    printf "\t${red}Status: ${gray}$description\n${normal}"
                    IFS=' ' read -ra filenames_array <<< "$filenames"
                    for filename in "${filenames_array[@]}"; do
                        printf "\t* ${gray}$filename\n${normal}"
                    done 
                done
               
                printf "${red}After resolving the errors, "
                read -p "press enter to continue"
                printf "${normal}\n"

                log=$(git cherry-pick --continue 2>&1)
                
                if [ $? -eq 0 ]; then
                    errors_resolved="true"
                    break
                fi
            done
        fi
        
        if [ $? -eq 0 ];then
            echo ""
            printf "${green}All selected $context was successfully upgraded.${normal}"
            echo ""
            if [ ! $silent ] && [ ! $remote ]; then
                printf "${yellow}Do you want to push applied changes to remote branch (Yes/No)? ${normal}"
                read yes_no
                yes_no=$(echo "$yes_no" | tr '[:upper:]' '[:lower:]')
                printf "${gray}You selected: $yes_no${normal}\n"
            fi    
            if [ "$yes_no" = "yes" ] || [ "$yes_no" = "y" ]; then
                if [ ! $remote ] || [ "$remote" = "true" ]; then
                    default_branch=${default_branch:-main}
                    remote=$default_branch
                    if [ ! $silent ]; then
                        printf "${yellow}Select the remote branch (default to '$remote'): ${normal}"
                        read remote
                        if [ ! $remote ]; then
                            remote=$default_branch
                        fi
                        
                    fi    
                fi
                if [ $remote ]; then
                    echo "Pushing all applied changes to remote branch '$remote' "
                    echo "Running: git push origin $remote"
                    git push origin $remote
                fi
            fi
        else
            printf "${gray}$log${normal}\n"    
            yes_no="no"
            echo ""
            printf "${red}Selected $context was NOT successfully applied.${normal}\n"
            if [ ! $silent ]; then
                printf "${yellow}Do you want to abort the upgrade-operation (Yes/No)? ${normal}"
                read yes_no
                yes_no=$(echo "$yes_no" | tr '[:upper:]' '[:lower:]')
                printf "${gray}You selected: $yes_no${normal}\n"

                if [ "$yes_no" = "yes" ] || [ "$yes_no" = "y" ]; then
                    printf "${gray}Running: git cherry-pick --abort${normal}"
                    log=$(git cherry-pick --abort)
                    if [ $? -eq 0 ];then
                        echo "The upgrade-operation aborted!"
                    else    
                        printf "${gray}$log${normal}\n"    
                        printf "${red}The upgrade-operation abort failed....${normal}"
                    fi
                fi    
            fi    
        fi
    fi
}

get_status_description() {
    case $1 in
        # Merge conflict status codes
        DD) echo "Merge conflict, both deleted";;
        AU) echo "Merge conflict, added by us";;
        UD) echo "Merge conflict, deleted by them";;
        UA) echo "Merge conflict, added by them";;
        DU) echo "Merge conflict, deleted by us";;
        AA) echo "Merge conflict, both added";;
        UU) echo "Merge conflict, both modified";;
        # Untracked and ignored
        ??) echo "Untracked";;
        !!) echo "Ignored";;
        *)  echo "Changes that need to be commited";;
    esac
}