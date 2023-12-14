#!/usr/bin/env bash

apply()
{
    if [ "$debug" ] && [ "$git_grep" ]; then
        echo "git_grep: $git_grep"
    fi
    if [ $help ]; then
        echo "${bold}smud apply${normal} [options]: Apply one or more productst to the repository."
        echo ""
        echo "Options:"
        echo "  --product=, -P=:"
        echo "      Apply only the selected product."
        echo "  --from-commit=,-FC=:"
        echo "      Apply only products ${bold}from${normal} a specific commit"
        echo "  --to-commit=,-TC=:"
        echo "      Apply only products ${bold}to${normal} a specific commit"
        echo "  --from-date,-FD:"
        echo "      Apply only products ${bold}from${normal} a specific date"
        show_date_help "from-date"
        echo "  --to-date,-TD:"
        echo "      Apply only products ${bold}to${normal} a specific date"
        show_date_help "to-date"
        echo "  --version,-V:"
        echo "      Apply only products ${bold}with${normal} a specific version"
        echo "      -G'chartVersion: $version' | -S'chartVersion: $version'"
        echo "  --stage=, -S=:"
        echo "      Apply only products on selected stage."
        echo "  --external-test,-ET:"
        echo "      Apply only products on external-test stage. Override --stage parameter"
        echo "  --production,-PROD:"
        echo "      Apply only products on production stage. Override --stage parameter"
        echo "  --silent:"
        echo "      Apply without question."
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
            echo "  # Apply all audit-product commits on all stages"
            echo "  smud apply --product=audit --remote=main"
            echo ""
        fi
        return
    fi

    if [ ! "$is_repo" ]; then
        printf "${red}'$(pwd)' is not a git repository! ${normal}\n"
        return
    fi

    has_commits=$(git log $commit_range --max-count=1 --no-merges $diff_filter $git_grep --pretty=format:"%H" -- $filter)
    if [ ! $has_commits ]; then
        printf "${gray}No products found.${normal}\n"   
        return
    fi

    yes_no="yes"
    if [ ! $silent ]; then
      git --no-pager log $commit_range --reverse --date=iso --no-merges $diff_filter $git_grep --pretty=format:"%C(#808080)%ad%Creset$col_separator%C(yellow)%h%Creset$col_separator$filter_product_name%s$separator" -- $filter
      echo ""
      printf "${yellow}Do you want to continue applying the selected products (Yes/No)? ${normal}"
      read yes_no
      yes_no=$(echo "$yes_no" | tr '[:upper:]' '[:lower:]')
      printf "${gray}You selected: $yes_no${normal}\n"
    fi  
    
    if [ "$yes_no" = "yes" ] || [ "$yes_no" = "y" ]; then
        commits=$(git log $from_commit^..$to_commit --reverse --no-merges $diff_filter $git_grep --pretty=format:"%H" -- $filter)
        commits=$(echo $commits| sed -e 's/\n/ /g')
        printf "${gray}Running: git cherry-pick [commits]...${normal}\n"   
        log=$(git cherry-pick $commits)
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
                printf "${yellow}Do you want to abort the apply-operation (Yes/No)? ${normal}"
                read yes_no
                yes_no=$(echo "$yes_no" | tr '[:upper:]' '[:lower:]')
                printf "${gray}You selected: $yes_no${normal}\n"

                if [ "$yes_no" = "yes" ] || [ "$yes_no" = "y" ]; then
                    printf "${gray}Running: git cherry-pick --abort${normal}"
                    log=$(git cherry-pick --abort)
                    if [ $? -eq 0 ];then
                        echo "The apply-operation aborted!"
                    else    
                        printf "${gray}$log${normal}\n"    
                        printf "${red}The apply-operation abort failed....${normal}"
                    fi
                fi    
            fi    
        fi
    fi
}