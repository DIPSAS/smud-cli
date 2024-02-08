#!/usr/bin/env bash

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
        echo "  --undo --date='two days ago':"
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

    if [ "$undo" ]; then
        reset_to_commit
        return
    fi

    local context="products"
    local upgrade_filter=$filter
    local yes_no="yes"
    if [ ! "$product" ]; then
        if [ ! "$silent" ]; then
            echo "No Products specified by [--products=, --product=, -P=] or [--all, -A]."
            ask yes_no $yellow "Do you want to upgrade the GitOps-model (Yes/No)?"
        fi
        if [ "$yes_no" = "yes" ]; then
            local upgrade_filter=$devops_model_filter
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

    IFS=$'\n';read -rd '' -a rev_list <<< "$rev_list"

    correlate_against_already_cherripicked rev_list already_cherry_picked_commits

    if [ ${#rev_list[@]} -eq 0 ]; then
        if [ $already_cherry_picked_commits -gt 0 ];then
            print_gray "All changes already cherry-picked!"           
        else
            print_gray "No $context found."           
        fi
        return
    fi

    # git_range="${rev_list[@]}"

    list 
    
    yes_no="yes"
    if [ ! "$silent" ]; then
      ask yes_no "$yellow" "Do you want to continue upgrading the selected $context (Yes/No)?"
    fi  
    local cherrypick_options="--keep-redundant-commits --allow-empty -x"
    local upgrade_error_code=0
    if [ "$yes_no" = "yes" ]; then
        commits="${rev_list[@]}"
        print_gray "Running: git cherry-pick [commits]...\n"   
        print_debug "$commits"
        # If there are any current unapplied changes, cherry pick will fail. Catch this.
        cherrypick_commits_command="git cherry-pick $commits $cherrypick_options"
        run_command cherry-pick --command-var=cherrypick_commits_command --return-var=log --skip-error --debug-title='Start cherry-pick' || error_message=$log

        # Check if cherry-pick in progress
        error_index="$(echo "$error_message" | grep "cherry-pick is already in progress" -c)"
        if [ $error_index -gt 0 ]; then
            error_message=""
            cherrypick_commits_command="git cherry-pick --continue $cherrypick_options"
            run_command cherry-pick --command-var=cherrypick_commits_command --return-var=log --debug-title='Continue cherry-pick' || error_message=$log
        fi

        # Check if cherry-pick was resolved
        error_index="$(echo "$error_message" | grep "The previous cherry-pick is now empty, possibly due to conflict resolution" -c)"
        if [ $error_index -gt 0 ]; then
            error_message=""
            cherrypick_commits_command="git cherry-pick --skip $cherrypick_options"
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
                    file=$(echo "$line" | cut -c -4)
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
                read -p "press [enter] to continue. To abort press [A][enter]. To skip commit press [S][enter]: " continue_or_abort
                lower continue_or_abort
                printf "${normal}\n"
                if [ "$continue_or_abort" = "a" ]; then
                    log=$(git cherry-pick --abort > /dev/null 2>&1 )
                    exit
                fi

                error_code=0
                error_message=""
                log=""
                errors_resolved="false"

                if [ "$continue_or_abort" = "s" ]; then
                    log=$(git cherry-pick --skip $cherrypick_options > /dev/null 2>&1 )
                    errors_resolved="true"
                else    
                    cherrypick_commits_command="git cherry-pick --continue $cherrypick_options"
                    run_command cherry-pick --command-var=cherrypick_commits_command --return-var=log --error-code error_code --debug-title='Continue cherry-pick' || error_message=$log
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
                yes_no=$(echo "$yes_no" | tr '[:upper:]' '[:lower:]')
                printf "${gray}You selected: $yes_no${normal}\n"
            fi    
            if [ "$yes_no" = "yes" ] || [ "$yes_no" = "y" ]; then
                if [ ! "$remote" ] || [ "$remote" = "true" ]; then
                    default_branch=${default_branch:-main}
                    remote=$default_branch
                    if [ ! "$silent" ]; then
                        printf "${yellow}Select the remote branch (default to '$remote'): ${normal}"
                        read remote
                        if [ ! "$remote" ]; then
                            remote=$default_branch
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
    local -n revision_list=$1
    local -n already_cherry_picked_commits_counter=$2
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
        if [ ${#revision_list[@]} -gt 0 ]; then
            print_gray "Number of revisions corrolated agains already cherry-picked commits: $normal${#revision_list[@]}"
        fi
    fi

}