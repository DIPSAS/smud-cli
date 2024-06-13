#!/usr/bin/env bash

print_verbose "**** START: functions-upgrade.sh"

trap clean_up INT

clean_up()
{
    abort_cherry_pick_command="git cherry-pick --abort"
    run_command abort-cherry-pick --command-from-var abort_cherry_pick_command --debug-title="Aborting cherry-pick"
    exit 0
}

upgrade()
{
    if [ "$debug" ] && [ "$git_grep" ]; then
        echo "git_grep: $git_grep"
    fi
    if [ "$help" ]; then
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
        echo "      --reset <commit> can be used as well."
        echo "  --undo --date='<date>'"
        echo "      Undo all changes back to specific date"
        echo "      --reset --date '<date>' can be used as well."
        echo "  --examples,-ex:"
        echo "      Show examples"
        if [ "$examples" ]; then 
            echo ""
            echo "Examples:"
            echo "  # Upgrade audit-product commits on all stages"
            echo "  smud upgrade --product=audit --remote=main"
            echo ""
            echo "  # Undo all changes to a specific commit"
            echo "  smud upgrade --undo 5de81ab0d7837b5e55c411141a824e2e323c5db2"
            echo "  smud upgrade --reset 5de81ab0d7837b5e55c411141a824e2e323c5db2"
            echo ""
            echo "  # Undo all changes to a specific date"
            echo "  smud upgrade --undo --date 'one week ago'"
            echo "  smud upgrade --reset --date '10 days ago'"
            echo "  smud upgrade --reset --date yesterday"
            echo ""
        fi
        return
    fi

    init

    exit_if_is_not_a_git_repository "Upgrade can only be executed on a git repository!"  

    if [ ! "$git_range" ]; then
        print_error "No revisions available to upgrade!"
        return
    fi

    if [ "$undo" ]; then
        reset_to_commit
        return
    fi

    local context="products"
    local upgrade_filter="$filter"
    local yes_no="yes"
    if [ ! "$product" ]; then
        if [ ! "$silent" ]; then
            echo "No Products specified by [--products=, --product=, -P=] or [--all, -A]."
            ask yes_no $yellow "Do you want to upgrade the GitOps-model (Yes/No)?"
        fi
        if [ "$yes_no" = "yes" ]; then
            local upgrade_filter="$devops_model_filter"
            local context="GitOps-model files"
            print_gray "Swithced to '$context' context"
        else
            return
        fi    
    fi
    printf "${white}Upgrade $context ready for installation:${normal}\n"

    local has_changes_command="git log $git_range --max-count=1 --no-merges --pretty=format:1 -- $upgrade_filter"
    run_command --has-commits --command-var=has_changes_command --return-var='has_commits' --debug-title='Check if any changes' || return
    if [ ! "$has_commits" ]; then
        print_gray "No $context found."   
        return
    fi
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
    old_SEP=$IFS
    IFS=$'\n';read -rd '' -a rev_list <<< "$rev_list"

    correlate_against_already_cherripicked rev_list already_cherry_picked_commits

    if [ ${#rev_list[@]} -eq 0 ]; then
        if [ $already_cherry_picked_commits -gt 0 ];then
            print_gray "All changes already cherry-picked!"           
        else
            print_gray "No $context found."           
        fi
        IFS=$old_SEP
        return
    fi
    IFS=$old_SEP

    # git_range="${rev_list[@]}"

    list 
    error_code=0
    yes_no="yes"
    if [ ! "$silent" ]; then
      ask yes_no "$yellow" "Do you want to continue upgrading the selected $context (Yes/No)?"
    fi  
    local cherrypick__continue_options="--keep-redundant-commits --allow-empty"
    local cherrypick_options="$cherrypick__continue_options -x"
    local upgrade_error_code=0
    if [ "$yes_no" = "yes" ]; then

        ensure_git_cred_is_configured

        commits="${rev_list[@]}"
        print_gray "Running: git cherry-pick [commits]...\n"   
        print_debug "$commits"
        # If there are any current unapplied changes, cherry pick will fail. Catch this.
        cherrypick_commits_command="git cherry-pick $commits $cherrypick_options"
        run_command cherry-pick --command-var=cherrypick_commits_command --return-var=log --skip-error --error-code error_code --debug-title='Start cherry-pick' || error_message="$log"

        # Check if cherry-pick in progress
        error_index="$(echo "$error_message" | grep "cherry-pick is already in progress" -c)"
        if [ $error_index -gt 0 ]; then
            error_code=0
            error_message=""
            cherrypick_commits_command="git cherry-pick --continue $cherrypick__continue_options"
            run_command cherry-pick --command-var=cherrypick_commits_command --return-var=log --error-code error_code --debug-title='Continue cherry-pick' || error_message="$log"
        fi

        # Check if cherry-pick was resolved
        error_index="$(echo "$error_message" | grep "The previous cherry-pick is now empty, possibly due to conflict resolution" -c)"
        if [ $error_index -gt 0 ]; then
            error_message=""
            error_code=0
            cherrypick_commits_command="git cherry-pick --skip"
            run_command cherry-pick --command-var=cherrypick_commits_command --return-var=log --error-code error_code --debug-title='Skip cherry-pick' || error_message="$log"
        fi

        # Loop until no conflicts
        # Print status in plain text after each file listing
        # If the conflict is UD (delete happened in remote) resolve it automatically using "merge-strategy theirs"
        if [ "$error_message" ]; then
            errors_resolved="false"
            if [ ! "$silent" ]; then
                printf "${red}Cherry-pick ran into errors that must be resolved manually.\n${normal}"
            fi
            #echo "$error_message"
            while [ "$errors_resolved" == "false" ]; do 
                files_status="$(git status -s)"

                declare -A status_map

                while IFS= read -r line; do
                    
                    # git diff  --pretty=format:''|sed -e 's/+/\n/g' -e 's/\r//g'|xargs
                    # echo "line:$line"
                    # Extract the file status
                    status_code="$(echo "$line" | cut -c -2)"
                    # Extract the file name
                    diff_command="git diff --pretty=format:''| grep -e '>>' -e '<<' -e '+ ' -e '- ' -e '++==' | sed -e 's/--- a\///g' -e 's/+++ b\///g' | sed -e 's/ +/+/g' -e 's/ -/-/g'|uniq"
                    run_command diff-command --command-var=diff_command --return-var=file --debug-title='Find Git Differences: '

                    if [ "$verbose" ]; then
                        print_verbose "Git Differences: $file"
                        git diff  --pretty=format:''|sed -e 's/+/\n/g' -e 's/\r//g'|xargs
                    fi

                    if [ ! "$file" ]; then
                        file="$(echo "$line" | cut -d ' ' -f 4|xargs)"
                        if [ ! "$file" ]; then
                            file="$(echo "$line" | cut -d ' ' -f 3|xargs)"
                        fi
                        if [ ! "$file" ]; then
                            file="$(echo "$line" | cut -d ' ' -f 2|xargs)"
                        fi
                    fi
                    # echo "status_code:$status_code"
                    # echo "file:$file"
                    # Add the file to the map where the status is the key
                     if [[ -n "${status_map["$status_code"]}" ]]; then
                        # If it exists, append the current file to the existing array
                        status_map["$status_code"]+=" $file"
                    else
                        # If it doesn't exist, create a new array with the current file
                        status_map["$status_code"]="$file"
                    fi
                done < <(git status -s)

                merge_conflict_status_codes="DD AU UD UA DU AA UU"
                untracked_status_code="??"
                if [ "$silent" ]; then
                    printf "${red}There is a merge conflict!\n${normal}"
                else
                    printf "${red}The follwing contains changes that must be resolved:\n${normal}" 
                fi

                for status_code in "${!status_map[@]}"; do
                    filenames="${status_map[$status_code]}"

                    description="$(get_status_description "$status_code")"
                    printf "\t${red}Status: ${gray}$description\n${normal}"
                    IFS=$'\n';read -rd '' -a filenames_array <<< "$filenames"
                    label=""
                    for filename in "${filenames_array[@]}"; do
                        filename="$(echo "$filename"| xargs)"
                        tab="\t*"
                        c=$(echo "$filename"|grep ":" -c)
                        if [ "${filename:0:1}" = "+" ] || [ "${filename:0:1}" = "-" ] || [ $c -gt 0 ]; then
                            tab="\t\t"
                            if [ ! "$label" ]; then
                                label="\t  Diffs:"
                                printf "$gray$label\n${normal}"    
                            elif [ "${filename:0:4}" = "++==" ]; then
                                printf "$tab $gray$filename \n${normal}"
                                color="$green"
                                continue
                            fi
                            
                        else
                            color="$red"
                            label=""
                        fi
                        printf "$tab $color$filename\n${normal}"
                    done 
                done

                if [ "$silent" ]; then
                    echo "Aborting the cherry-pick process."
                    cherrypick_abort_command="git cherry-pick --abort"
                    run_command cherry-pick-abort --command-var=cherrypick_abort_command --return-var=dummy --skip-error --debug-title='Abort cherry-pick'
                    if [ ! "$error_code" ] || [ "$error_code" = "0" ]; then
                        error_code=1
                    fi

                    exit $error_code
                fi

                printf "${red}After resolving the errors, "
                read -p "press [enter] to continue. To abort press [A][enter]. To skip commit press [S][enter]: " continue_or_abort
                lower continue_or_abort
                printf "${normal}\n"
                if [ "$continue_or_abort" = "a" ]; then
                    error_code=0
                    cherrypick_abort_command="git cherry-pick --abort"
                    run_command cherry-pick-abort --command-var=cherrypick_abort_command --return-var=dummy --skip-error --debug-title='Abort cherry-pick'
                    exit
                fi

                error_code=0
                error_message=""
                log=""
                errors_resolved="false"

                if [ "$continue_or_abort" = "s" ]; then
                    log="$(git cherry-pick --skip > /dev/null 2>&1)"
                    errors_resolved="true"
                else    
                    cherrypick_commits_command="git cherry-pick --continue $cherrypick__continue_options"
                    run_command cherry-pick --command-var=cherrypick_commits_command --return-var=log --error-code error_code --debug-title='Continue cherry-pick' || error_message="$log"
                    if [ $error_code -eq 0 ]; then
                        errors_resolved="true"
                        break
                    else

                        if [ $error_code -eq 128 ]; then
                            error_index="$(echo "$error_message" | grep "no cherry-pick or revert in progress" -c)"
                            if [ $error_index -gt 0 ]; then
                                error_code=0
                                error_message=""
                                errors_resolved="true"
                            fi
                        fi
                        if [ $error_code -gt 0 ]; then
                            print_error "Cherry-pick continue failed: errorCode: $error_code, error: '$error_message'"
                        fi
                    fi
                fi

                # Clear the status_map
                unset status_map
            done
        fi
        
        if [ $? -eq 0 ];then
            echo ""
            printf "${green}All selected $context was successfully upgraded.${normal}"
            echo ""
            if [ ! "$silent" ] && [ ! "$remote" ]; then
                printf "${yellow}Do you want to push applied changes to remote branch $remote (Yes/No)? ${normal}"
                read yes_no
                yes_no="$(echo "$yes_no" | tr '[:upper:]' '[:lower:]')"
                printf "${gray}You selected: $yes_no${normal}\n"
            fi    
            if [ "$yes_no" = "yes" ] || [ "$yes_no" = "y" ]; then
                if [ ! "$remote" ] || [ "$remote" = "true" ]; then
                    remote="$default_branch"
                    if [ ! "$silent" ]; then
                        printf "${yellow}Select the remote branch (default to '$remote'): ${normal}"
                        read remote
                        if [ ! "$remote" ]; then
                            remote="$default_branch"
                        fi
                        
                    fi    
                fi
                if [ $remote ] && [ ! "$skip_push" ]; then
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
            if [ ! "$silent" ]; then
                printf "${yellow}Do you want to abort the upgrade-operation (Yes/No)? ${normal}"
                read yes_no
                yes_no="$(echo "$yes_no" | tr '[:upper:]' '[:lower:]')"
                printf "${gray}You selected: $yes_no${normal}\n"

                if [ "$yes_no" = "yes" ] || [ "$yes_no" = "y" ]; then
                    printf "${gray}Running: git cherry-pick --abort${normal}"
                    log="$(git cherry-pick --abort)"
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

reset_to_commit()
{
    if [ "$undo" = "true" ] && [ ! "$undo_date" ]; then
        print_error "You must add the commit or --date to the --undo flag. Ex: --undo b3..., or --undo --date yesterday"
        return
    fi
    if [ "$undo_date" ]; then
        undo_date_range="--before $(echo "$undo_date"| sed -e 's/ /./g')" 
        local undo_commit_from_datecommand="git log $undo_date_range --pretty=format:'%H' --max-count=1"    
        run_command --find-undo-commit --command-var=undo_commit_from_datecommand --return-var='undo' --debug-title='Find undo commit-id from undo-date'
        if [ ! "$undo" ]; then
            print_error "Unable to find undo commit-id based on undo commit-date '$undo_date'"
            return
        fi

    fi
    local has_undo_commit_command="git log $undo --max-count=1 --no-merges --oneline"
    run_command --has-commits --command-var=has_undo_commit_command --return-var='has_undo_commit' --debug-title='Check if undo commit exists' || 
    {
        print_error "Unabled to find commit '$undo'.\nUndo terminated...\n"
        return
    }
    if [ ! "$has_undo_commit" ]; then
        print_gray "No commit '$$undo' found. Undo terminated..."   
        return
    fi
    yes_no="yes"
    if [ ! "$silent" ]; then
        ask yes_no $yellow "Do you really want to reset to [$has_undo_commit]?\nThis is a destructive command. All changes newer than that commit will be lost!"
    fi
    if [ "$yes_no" = "yes" ]; then
        local flag="--hard"
        if [ "$soft" ]; then
            local flag="--soft"
        fi
        local git_reset_hard_command="git reset $flag $undo"
        run_command --reset-to-commit --command-var=git_reset_hard_command --return-var='reset_result' --debug-title="Reset '$default_branch' to commit '$undo'" || 
        {
            print_error "Failed to reset default branch '$default_branch' to commit '$undo'\n"
            return
        }
        print_color $green "Default branch '$default_branch' successfully reset to commit '$undo'\n"
    fi
}

correlate_against_already_cherripicked()
{
    local -n revision_list="$1"
    local -n already_cherry_picked_commits_counter="$2"
    already_cherry_picked_commits_counter=0
    rev_list_checked=()
    local has_cherrypicked_commits=""
    local cherrypicked_changes_command="git log HEAD --max-count=1 --no-merges --pretty=format:1  --grep cherry.picked.from.commit -- $upgrade_filter"
    run_command --has-commits --command-var=cherrypicked_changes_command --return-var='has_cherrypicked_commits' --skip-error --debug-title='Check fo already cherry-picked changes' || return
    if [ "$has_cherrypicked_commits" ]; then

        print_debug "Compute revision corrolated agains already cherry-picked commits..."
        local cherrypicked_commits=""
        local cherrypicked_changes_command="git log HEAD --no-merges --grep cherry.picked.from.commit --pretty=format:%b -- $upgrade_filter"
        run_command --has-commits --command-var=cherrypicked_changes_command --return-var='cherrypicked_commits' --skip-error --debug-title='Collect already cherry-picked changes' || return
        local cherrypicked_commits=$(echo "$cherrypicked_commits"| sed -e 's/(cherry picked from commit //g' -e 's/)//g' -e '')
        if [ "$debug" ]; then
            number_of_cherry_picked_commits=$(echo "$cherrypicked_commits" | wc -w)

            print_gray "Number of already cherry-picked commits found: $normal$number_of_cherry_picked_commits"
            print_gray "Number of original revisions from upstream/source: $normal${#revision_list[@]}"
        fi
        for rev in "${revision_list[@]}"
        do
            local c=$(echo "$cherrypicked_commits" | grep "$rev" -c)
            if [ "$c" = "0" ]; then
            # if [[ ! " ${cherrypicked_commits_arr[@]} " =~ " $rev " ]]; then
                rev_list_checked+=("$rev")
                print_verbose "Added commit corrolated agains already cherry-picked commits: $rev ${#rev_list_checked[@]} -- $c"
            else
                print_verbose "Ignored commit corrolated agains already cherry-picked commits: $rev -- $c"
                already_cherry_picked_commits=$((already_cherry_picked_commits+1))
            fi
        done
        revision_list=("${rev_list_checked[@]}")
        if [ ${#revision_list[@]} -gt 0 ] && [ ! "$silent" ]; then
            print_gray "Number of revisions corrolated agains already cherry-picked commits: $normal${#revision_list[@]}"
        fi
    fi

}
ensure_git_cred_is_configured()
{
    local user_name="$(git config --get user.name)"
    local user_email="$(git config --get user.email)"

    if [ ! "$user_name" ] || [ ! "$user_email" ]; then
        if [ ! "$user_name" ]; then
            local user_token="$(git config --get remote.origin.url | sed -e 's/https:\/\///g' | cut -d '@' -f 1)"    
            local c="$(echo "$user_token"|grep ':' -c)"
            
            if [ $c -gt 0 ]; then
                local user_name="$(echo "$user_token" | cut -d ':' -f 1)"
            fi
        fi

        if [ ! "$user_name" ]; then
            local user_name="githubservicesmud"
        fi

        if [ ! "$user_email" ]; then
            local user_email="$user_name@dips.no"
        fi

        local user_name_ask="$user_name"
        local user_email_ask="$user_email"
        if [ ! "$silent" ]; then
            ask user_name_ask $blue "Please configure git user.name (Push ENTER to use '$user_name_ask'): "
            ask user_email_ask $blue "Please configure git user.email (Push ENTER to use '$user_email_ask'): "
            if [ ! "$user_name_ask" ]; then
                local user_name_ask="$user_name"
            fi
            if [ ! "$user_email_ask" ]; then
                local user_email_ask="$user_email"
            fi
        fi
        
        local dummy="$(git config --unset user.name)"
        local dummy="$(git config --unset user.email)"
        local dummy="$(git config --add user.name "$user_name_ask" )"
        local dummy="$(git config --add user.email "$user_email_ask" )"
    fi
}

print_verbose "**** END: functions-upgrade.sh"