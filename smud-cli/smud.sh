#!/bin/bash -i
. $(dirname "$0")/install-cli.sh
. $(dirname "$0")/include.sh "$@"

command=$1

if [ ! $command ] || [ "$command" = "--help" ]; then

    changes=(`cat $(dirname "$0")/CHANGELOG.md |sed -e 's/## Version /\n/g'`)

    # Print information
    echo "${bold}smud${normal}: Help dealing with products in the GitOps repository."
    echo "      Version "${changes[0]}""
    echo ""

    echo "Commands:"
    echo "  update-cli    Download and update the smud CLI. Required ${bold}curl${normal} installed on the computer" 
    echo "  version       Show the version of smud CLI" 
    echo "  list          List products ready for installation or current products installed."

    if [ ! $is_smud_dev_repo ]; then
      echo "  apply         Apply one or more productst to the repository."
      echo "  set-upstream  Set upstream https://github.com/DIPSAS/DIPS-GitOps-Template.git"
      echo "  upstream      Fetch upstream/main"
    else
        printf "${gray}Unavaible commands:${normal}\n"
        printf "  ${gray}apply         Apply one or more productst to the repository.${normal}\n"
        printf "  ${gray}set-upstream  Set upstream https://github.com/DIPSAS/DIPS-GitOps-Template.git${normal}\n"
        printf "  ${gray}upstream      Fetch upstream/main${normal}\n"

    fi

    echo "Usage:"
    echo "  smud <command> [options]"
fi

if [ $verbose ]; then
      echo "command: $command" 
fi

if [ "$command" = "version" ]; then
    changes=(`cat $(dirname "$0")/CHANGELOG.md |sed -e 's/## Version /\n/g'`)
    printf "${bold}smud version${normal}: Show the version of smud CLI\n" 
    echo "Current Version "${changes[0]}""
    echo ""
    echo "Changelog:"
    cat $(dirname "$0")/CHANGELOG.md| sed -e 's/## //g'
    echo ""

fi

if [ "$command" = "update-cli" ]; then
    if [ $help ]; then
        printf "${bold}smud update-cli${normal}: Download and update the smud CLI.\n"
        printf "                 Required ${bold}curl${normal} installed on the computer.\n"
        echo ""
        echo "> Download from https://api.github.com/repos/DIPSAS/smud-cli/contents/smud-cli"    
        echo "> Copy downloaded content to ~/smud-cli folder"    
        echo "> Prepare ~/.bashrc to load ~/smud-cli/.bash_aliases"    
        exit
    fi

    printf "${bold}smud update-cli${normal}: Download and update the smud CLI.\n"
    echo ""

    . $(dirname "$0")/download-and-install-cli.sh
    exit
fi

if [ "$command" = "set-upstream" ]; then

    if [ $help ]; then
        echo "${bold}smud set-upstream${normal}: Set upstream https://github.com/DIPSAS/DIPS-GitOps-Template.git"
        exit
    fi

    git remote add upstream https://github.com/DIPSAS/DIPS-GitOps-Template.git
    exit
fi

if [ "$command" = "upstream" ]; then
    if [ $help ]; then
        echo "${bold}smud upstream${normal}: Fetch upstream/main"
        exit
    fi

    git fetch upstream
    exit
fi


if [ "$command" = "list" ]; then
    if [ $help ]; then
        echo "${bold}smud list${normal} [options]: List ${bold}updated/new${normal} products ready for installation or current products installed."
        echo ""
        echo "Options:"
        echo "  --product=, -P=:"
        echo "      Select only the selected product."
        echo "  --stage=, -S=:"
        echo "      Select only products on selected stage."
        echo "  --external-test,-ET:"
        echo "      Select only products on external-test stage. Override --stage parameter"
        echo "  --production,-PROD:"
        echo "      Select only products on production stage. Override --stage parameter"
        echo "  --new:"
        echo "      Select only ${bold}new${normal} products"
        echo "  --installed,-I:"
        echo "      Select only ${bold}current${normal} products installed"
        echo "  --from-commit,-FC:"
        echo "      Select only products ${bold}from${normal} a specific commit"
        echo "  --to-commit,-TC:"
        echo "      Select only products ${bold}to${normal} a specific commit"
        echo ""
        echo "Examples:"
        echo "  # List all updated products on all stages"
        echo "  smud list"
        echo ""
        echo "  # List audit-product on all stages"
        echo "  smud list --product=audit"
        echo "  smud list -P=audit"
        echo ""
        echo "  # List audit-product on external-test stage"
        echo "  smud list --product=audit --external-test"
        echo "  smud list --product=audit -ET"
        echo "  smud list --product=audit --stage=external-test"
        echo ""
        echo "  # List audit-product on production stage"
        echo "  smud list --product=audit --production"
        echo "  smud list --product=audit -PROD"
        echo "  smud list --product=audit --stage=production"

        echo ""
        echo "  # List all new products on external-test stage"
        echo "  smud list --new --external-test"
        echo "  smud list --new -ET"

        exit
    fi

    if [ ! "$separator" ] && [ ! "$hide_title" ]; then
        if [ $new ]; then
            diff_filter='--diff-filter=ACMRT'
            printf "${white}List new products ready for installation:${normal}\n"
        elif [ $installed ]; then
          printf "${white}List current products installed:${normal}\n"
        else
            printf "${white}List new or updated products ready for installation:${normal}\n"
        fi    
    fi    
    if [ $installed ]; then
      app_yaml_files=$(ls $app_filter)
      for app_yaml in $app_yaml_files
      do
        stage_dir=$(dirname "$app_yaml")
        app_stage=${selected_stage:-`basename "$stage_dir"`}
        app_name=$selected_product
        if [ ! "$app_name" ];then         
          app_name=$(dirname "$stage_dir")
          app_name=$(basename "$app_name")
        fi  
        date=`ls -l --time-style=long-iso $app_yaml | awk '{print $6,$7}'| sort   ` 
        version=`cat $app_yaml | grep chartVersion: | cut --delimiter=: -f 2 | xargs | tr -d ['\n','\r'] | cut -f1 --delimiter=#`
        version=`printf %-14s "$version"`
        printf "${gray}$date${normal}$col_separator${yellow}$version${normal}$col_separator${normal}Product ${bold}$app_name${normal} from ${bold}$app_stage${normal} stage\n"
      done
      exit
    fi

    if [ $verbose ];then
        echo "can_list_direct: $can_list_direct"
    fi

    if [ ! "$is_repo" ]; then
        echo "${red}'${pwd}' is not a git repository! ${normal}"
        exit
    fi

    if [ "$can_list_direct" ]; then
        git --no-pager log $commit_range --reverse --date=iso --no-merges $diff_filter --pretty=format:"%C(#808080)%ad%Creset$col_separator%C(yellow)%h%Creset$col_separator$filter_product_name%s$separator" -- $filter
        echo ""
        exit
    fi
  
    commits=$(git log $commit_range --reverse --no-merges $diff_filter --pretty=format:"%H" -- $filter)

    if [ $verbose ];then
        ncommits=0
        if [ ! "$commits" == "" ];then
            ncommits=$(echo $commits| sed -e 's/ /\n/g' | grep '' -c )
        fi    
        echo "Number of commits by filter '$filter': $ncommits"
    fi
    last_files=()
    last_product_name=""
    for commit in $commits
    do
        if [ $verbose ];then
            echo "commit: $commit"
        fi

        files=$(git show $commit $diff_filter --pretty="" --name-only  )
        product_name=$filter_product_name
        show_commit=1
        file_index=0
        file_not_exist=0
        for file in $files
        do
            file_index=$((file_index+1))
            if [ $verbose ];then
                echo "file: $file"
            fi
            
            if [ $new ] && [ ! -f $file ];then
                file_not_exist=$((file_not_exist+1))
            fi

            if [ "$is_smud_gitops_repo" ] && [ ! "$product_name" ]; then
                if printf '%s\0' "${last_files[@]}" | grep -qwz $file; then
                    product_name=$last_product_name
                    # echo "in_array: $file $product_name"
                    continue
                fi    
                DIRP=$(dirname "$file")
                while [ ! "$product_name"  ]
                do
                    DIRC=$DIRP
                    DIRP=$(dirname "$DIRC")
                    
                    if [ "$DIRP" = "products" ];then
                        product_name="[$(echo $DIRC | sed -e "s/products\///g")] "
                        break
                    fi

                    if [ ! "$DIRP" ] || [ "$DIRP" = "." ];then  
                        break
                    fi
                done
            fi
        done
        last_files=$files
        last_product_name=$product_name

        if [ $new ];then
            show_commit=0
            if [ $file_index -eq $file_not_exist ] && [ $file_index -gt 0 ]; then
                show_commit=1
            fi
        fi
        
        if [ $show_commit -eq 1 ];then
            if [ $verbose ];then
                echo "Show commit $commit $product_name"
            fi

            git log $commit --max-count=1 --date=iso --no-merges --pretty=format:"%C(#808080)%ad%Creset$col_separator%C(yellow)%h%Creset$col_separator$product_name%s$separator"
        fi
    done    
    exit
fi


if [ "$command" = "apply" ]; then
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
        exit
    fi

    if [ ! "$is_repo" ]; then
        echo "${red}'${pwd}' is not a git repository! ${normal}"
        exit
    fi

    if [ ! "$is_repo" ]; then
        echo "${red}'${pwd}' is not a git repository! ${normal}"
        exit
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
   
fi
