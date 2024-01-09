list()
{
    if [ "$debug" ] && [ "$git_grep" ]; then
        echo "git_grep: $git_grep"
    fi
    if [ $help ]; then
        echo "${bold}smud list${normal} [options]: List ${bold}updated/new${normal} products ready for installation or current products installed."
        echo ""
        echo "Options:"
        echo "  --products=, --product=, -P=:"
        echo "      Select one or more products."
        echo "  --all=, -A=:"
        echo "      Select all products."
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

    if [ ! "$is_repo" ]; then
        printf "${red}'$(pwd)' is not a git repository! ${normal}\n"
        return
    fi

    if [ ! "$product" ]; then
        show_gitopd_changes
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

    
    has_commits="$(git log $commit_range $date_range --max-count=1 --no-merges $git_grep $diff_filter --pretty=format:\"%H\" -- $filter)"
    if [ ! $has_commits ]; then
        printf "${gray}No products found.${normal}\n"   
        return 
    fi

    files=$(git log $commit_range $date_range --no-merges --name-only $git_grep --diff-filter=ACMRTUB --pretty=COMMIT:"%H" -- $filter)

    git_stages=($selected_stage)
    git_products=()
    commit=""
    declare -A product_versions

    
    for file in $files:
    do
        c=$(echo $file | grep COMMIT: -c)
        if [ $c -gt 0 ]; then
            commit=$(echo $file| sed -e 's/COMMIT://g')
        else
            parsed_stage=$(echo "$file" | cut -d'/' -f3)
            parsed_product=$(echo "$file" | cut -d'/' -f2)

            if [ ! "$parsed_stage" = "product.yaml" ]; then
                if [[ ! " ${git_stages[@]} " =~ " $parsed_stage " ]]; then
                    git_stages+=("$parsed_stage")
                fi
            fi

            if [[ ! " ${git_products[@]} " =~ " $parsed_product " ]]; then
                git_products+=("$parsed_product")
            fi

            product_info=${product_versions[${parsed_product}]}
            if [ ! "$product_info" ] && [ "$commit" ]; then
                c=$(echo $file | grep app.yaml -c)
                if [ $c -gt 0 ]; then
                    product_version="$(git --no-pager show $commit:$file $git_grep --diff-filter=ACMRT | grep chartVersion: | cut --delimiter=: -f 2 | xargs | tr -d ['\n','\r'] | cut -f1 --delimiter=#)"

                    product_versions[$parsed_product]="$product_version|$commit"
                    
                    # echo "product: $parsed_product, version: $version"
                fi
            fi
        fi

    done
    
    git_products=($(echo "${git_products[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
    git_stages=($(echo "${git_stages[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

    # echo "products: ${git_products[@]}"
    # echo "stages: ${git_stages[@]}"

    n_col0_len=40
    n_col1_len=14
    n_col2_len=14
    for stage in ${git_stages[@]}
    do
        printf "\n$stage:\n"
        printf "`printf %-${n_col0_len}s "PRODUCTS"` `printf %-${n_col1_len}s "CURRENT VER."` `printf %-${n_col2_len}s "NEW VER."` FILES\n"
        for git_product in ${git_products[@]}
        do
            current_version=""
            new_version=""
            commit=""    
            product_info=${product_versions[${git_product}]}
            if [ "$product_info" ]; then
                new_version="$(echo $product_info | cut -d "|" -f 1)"
                commit="$(echo $product_info | cut -d "|" -f 2)"
                # echo "new_version: [$new_version]"
                # echo "commit: [$commit]"
            fi
            
            product_path="products/$git_product"
            app_file="$product_path/$stage/app.yaml"
            if [ -f $app_file ]; then
                current_version=`cat $app_file | grep chartVersion: | cut --delimiter=: -f 2 | xargs | tr -d ['\n','\r'] | cut -f1 --delimiter=#`
            fi


            stage_filter=":$product_path/$stage/** $product_path/product.yaml"
            files_str=""
            if [ "$new_version" ]; then
                files_str="$(git log $commit --reverse --date=iso --no-merges --name-only --pretty= -- $stage_filter)"
            else    
                files_str="$(git log $commit --reverse --date=iso --no-merges --name-only $git_grep $diff_filter --pretty= -- $stage_filter)"
            fi 
            
            files_str=`echo "${files_str[@]}" | sort | uniq`
            replace_regex="s/products\/$git_product/./g" 

            print_git_product=`printf %-${n_col0_len}s "$git_product"`
            print_current_version=`printf %-${n_col1_len}s "$current_version"`
            print_new_version=`printf %-${n_col2_len}s "$new_version"`
            printf "$print_git_product $print_current_version $print_new_version $(echo $files_str | sed -e $replace_regex)\n"
            
        done    
    done
    echo ""
}
