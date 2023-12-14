list()
{
    if [ "$debug" ] && [ "$git_grep" ]; then
        echo "git_grep: $git_grep"
    fi
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
        echo "  --from-date,-FD:"
        echo "      Select only products ${bold}from${normal} a specific date"
        show_date_help "from-date"
        echo "  --to-date,-TD:"
        echo "      Select only products ${bold}to${normal} a specific date"
        show_date_help "to-date"
        echo "  --version,-V:"
        echo "      Select only products ${bold}with${normal} a specific version"
        echo "      -G'chartVersion: $version' | -S'chartVersion: $version'"
        echo "  --examples,-ex:"
        echo "      Show examples"
        if [ "$examples" ]; then 
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
        fi
        return
    fi

    if [ ! "$separator" ] && [ ! "$hide_title" ]; then
        # print title
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
        no_products_found="true"
        if [ -d "products" ]; then  
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
                no_products_found=""
                date=`ls -l --time-style=long-iso $app_yaml | awk '{print $6,$7}'| sort   ` 
                grep_for_version=`cat $app_yaml | grep chartVersion: | cut --delimiter=: -f 2 | xargs | tr -d ['\n','\r'] | cut -f1 --delimiter=#`
                grep_for_version=`printf %-14s "$grep_for_version"`
                printf "${gray}$date${normal}$col_separator${yellow}$grep_for_version${normal}$col_separator${normal}Product ${bold}$app_name${normal} from ${bold}$app_stage${normal} stage\n"
            done
        fi
        if [ $no_products_found ]; then
            printf "${gray}No products found.${normal}\n"    
        fi
        exit
    fi

    if [ ! "$is_repo" ]; then
        echo "${red}'${pwd}' is not a git repository! ${normal}"
        exit
    fi
    git_log="git log $commit_range $date_range --max-count=1 --no-merges $git_grep $diff_filter --pretty=format:\"%H\" -- $filter"

    if [ $verbose ]; then
        printf "${gray}$(echo "$git_log" | sed -e 's/%/%%/g')${normal}\n"    
    fi
    has_commits="$(git log $commit_range $date_range --max-count=1 --no-merges $git_grep $diff_filter --pretty=format:\"%H\" -- $filter)"
    if [ ! $has_commits ]; then
        printf "${gray}No products found.${normal}\n"   
        printf "${gray}has_commit=[$has_commits]${normal}\n"   
        exit 
    fi
    if [ "$can_list_direct" ]; then
        git_log="git --no-pager log $commit_range $date_range --reverse --date=iso --no-merges $git_grep $diff_filter --pretty=format:\"%C(#808080)%ad%Creset$col_separator%C(yellow)%h%Creset$col_separator$filter_product_name%s$separator\" -- $filter"
        if [ $verbose ]; then
            printf "${gray}$(echo "$git_log" | sed -e 's/%/%%/g')${normal}\n"    
        fi
        git --no-pager log $commit_range $date_range --reverse --date=iso --no-merges $git_grep $diff_filter --pretty=format:"%C(#808080)%ad%Creset$col_separator%C(yellow)%h%Creset$col_separator$filter_product_name%s$separator" -- $filter
        
        echo ""
        return
    fi
  

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

            git log $commit --max-count=1 --date=iso --no-merges $git_grep --pretty=format:"%C(#777777)%ad%Creset$col_separator%C(yellow)%h%Creset$col_separator$product_name%s$separator"
        fi
    done    
}
