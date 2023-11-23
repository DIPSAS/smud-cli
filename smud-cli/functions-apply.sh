#!/usr/bin/env bash

apply()
{
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
        echo "  --undo=<commit>:"
        echo "      Undo all changes back to specific commit"
        echo ""
        echo "Examples:"
        echo "  # Apply all audit-product commits on all stages"
        echo "  smud apply --product=audit --remote=main"
        echo ""
        return
    fi

    if [ ! "$is_repo" ]; then
        echo "${red}'${pwd}' is not a git repository! ${normal}"
        return
    fi

    has_commits=$(git log $commit_range --max-count=1 --no-merges $diff_filter --pretty=format:"%H" -- $filter)
    if [ ! $has_commits ]; then
        printf "${gray}No products found.${normal}\n"   
        return
    fi

    yes_no="yes"
    if [ ! $silent ]; then
      git --no-pager log $commit_range --reverse --date=iso --no-merges $diff_filter --pretty=format:"%C(#808080)%ad%Creset$col_separator%C(yellow)%h%Creset$col_separator$filter_product_name%s$separator" -- $filter
      echo ""
      printf "Do you want to continue applying the selected products (Yes/No)? "
      read yes_no
      yes_no=$(echo "$yes_no" | tr '[:upper:]' '[:lower:]')
      echo "You selected: $yes_no"
    fi  
    
    if [ "$yes_no" = "yes" ] || [ "$yes_no" = "y" ]; then
        commits=$(git log $from_commit^..$to_commit --reverse --no-merges $diff_filter --pretty=format:"%H" -- $filter)
        commits=$(echo $commits| sed -e 's/\n/ /g')
        echo "Running: git cherry-pick [commits]"
        git cherry-pick $commits
        if [ $? -eq 0 ];then
            echo ""
            echo "All selected products was successfully applied."
            echo ""
            if [ ! $silent ] && [ ! $remote ]; then
                printf "Do you want to push applied changes to remote branch (Yes/No)? "
                read yes_no
                yes_no=$(echo "$yes_no" | tr '[:upper:]' '[:lower:]')
                echo "You selected: $yes_no"
            fi    
            if [ "$yes_no" = "yes" ] || [ "$yes_no" = "y" ]; then
                if [ ! $remote ] || [ "$remote" = "true" ]; then
                    remote=""
                    if [ ! $silent ]; then
                        printf "Select the remote branch (default to 'main'): "
                        read remote
                        remote="${remote:-main}"
                    fi    
                fi
                if [ $remote ]; then
                    echo "Pushing all applied changes to remote branch '$remote' "
                    echo "Running: git push origin $remote"
                    git push origin $remote
                fi
            fi
        else
            yes_no="no"
            echo ""
            echo "Selected products was NOT successfully applied."
            if [ ! $silent ]; then
                printf "Do you want to abort the apply-operation (Yes/No)? "
                read yes_no
                yes_no=$(echo "$yes_no" | tr '[:upper:]' '[:lower:]')
                echo "You selected: $yes_no"

                if [ "$yes_no" = "yes" ] || [ "$yes_no" = "y" ]; then
                    echo "Running: git cherry-pick --abort"
                    git cherry-pick --abort
                fi    
            fi    
        fi
    fi
}