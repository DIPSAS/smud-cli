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
        printf "${red}'$(pwd)' is not a git repository! ${normal}\n"
        return
    fi

    if [ ! "$product" ]; then
        echo "Missing options:"
        echo "  Products must be specified by [--products=, --product=, -P=] or [--all, -A]"
        return
    fi

    # Using commit or date ranges we only want to apply the latest commit in this range which is handled using --max-count=1
    has_commits=$(git log $commit_range $date_range --max-count=1 --no-merges $diff_filter $git_grep --pretty=format:"%H" -- $filter)

    if [ ! $has_commits ]; then
        printf "${gray}No products found.${normal}\n"   
        return
    fi

    yes_no="yes"
    if [ ! $silent ]; then
      list
      echo ""
      printf "${yellow}Do you want to continue upgrading the selected products (Yes/No)? ${normal}"
      read yes_no
      yes_no=$(echo "$yes_no" | tr '[:upper:]' '[:lower:]')
      printf "${gray}You selected: $yes_no${normal}\n"
    fi  
    
    if [ "$yes_no" = "yes" ] || [ "$yes_no" = "y" ]; then
        commits=$(git log $from_commit^..$to_commit $date_range  --reverse --no-merges $diff_filter $git_grep --pretty=format:"%H" -- $filter)
        commits=$(echo $commits| sed -e 's/\n/ /g')
        printf "${gray}Running: git cherry-pick [commits]...${normal}\n"   
        
        # If there are any current unapplied changes, cherry pick will fail. Catch this.
        log=$(git cherry-pick $commits 2>&1) || error_message="$log"

        # Check if cherry-pick in progress
        error_index="$(echo "$error_message" | grep "cherry-pick is already in progress" -c)"
        if [ $error_index -gt 0 ]; then
            error_message=""
            log=$(git cherry-pick --continue 2>&1) || error_message="$log"
        fi

        # Check if cherry-pick was resolved
        error_index="$(echo "$error_message" | grep "The previous cherry-pick is now empty, possibly due to conflict resolution" -c)"
        if [ $error_index -gt 0 ]; then
            error_message=""
            log=$(git cherry-pick --skip 2>&1) || error_message="$log"
        fi

        # Loop until no conflicts
        if [ -n "$error_message" ]; then
            errors_resolved="false"
            printf "${red}Cherry-pick ran into errors that must be resolved manually.\n${normal}"
            #echo "$error_message"
            while [ "$errors_resolved" == "false" ]; do 
                paths_with_merge_conflicts=()
                paths_with_uncommited_changes=()
                paths_untracked=()
                files_status=$(git status -s)
                merge_conflict_status_codes="DD AU UD UA DU AA UU"
                untracked_status_code="??"
                
                while IFS= read -r line; do
                    # Extract the file status
                    status=$(echo "$line" | awk '{print $1}')
                    # Extract the file name
                    file=$(echo "$line" | awk '{$1=""; print $0}' | xargs)
                    
                    # Check if its a merge conflict
                    is_merge_conflict="$(echo "$merge_conflict_status_codes" | grep -w "$status" -c)"
                    if [ $is_merge_conflict -gt 0 ]; then
                        paths_with_merge_conflicts+=("$file")
                    # Check if there are files which has not been added
                    elif [[ "$untracked_status_code" == "$status" ]]; then
                        paths_untracked+=("$file")
                    # Ramaining files are assumed uncommited changes
                    else
                        paths_with_uncommited_changes+=("$file")
                    fi
                done < <(git status -s)
            
                if [ -n "${paths_with_merge_conflicts}" ]; then
                    printf "${red}The following paths contain merge conflicts that must be resolved:\n${normal}"
                    for path in "${paths_with_merge_conflicts[@]}"; do
                        printf "\t* ${red}${path}\n${normal}"
                    done
                fi

                if [ -n "${paths_untracked}" ]; then
                    printf "${red}The following paths have not been added yet:\n${normal}"
                    for path in "${paths_untracked}"; do
                        printf "\t* ${red}${path}\n${normal}"
                    done
                fi
                
                if [ -n "${paths_with_uncommited_changes}" ]; then
                    printf "${red}The following paths have changes that must be commited:\n${normal}"
                    for path in "${paths_with_uncommited_changes[@]}"; do
                        printf "\t* ${red}${path}\n${normal}"
                    done
                fi         

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
            printf "${green}All selected products was successfully applied.${normal}"
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
            printf "${red}Selected products was NOT successfully applied.${normal}\n"
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