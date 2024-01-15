declare -A product_infos


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
        if [ ! "$stage" = "development" ] && [ ! "$stage" = "internal-test" ]; then
            printf "${gray}No products found.${normal}\n"   
            return 
        fi
    fi
    product_name=""
    files=$(git log $commit_range $date_range --no-merges --name-only $git_grep --diff-filter=ACMRTUB --pretty=COMMIT:"%H|%at" -- $filter)

    product_stages=()
    product_names=()
    commit=""

    product_files=()
    
    for line in $files:
    do
        c=$(echo $line | grep COMMIT: -c)
        # echo "line: $line"
        if [ $c -gt 0 ]; then
            complete_version

            # if [ "$stage_product_name" = "aom-ordersampling/external-test" ]; then
            #     break
            # fi

            file=""
            product_info=""
            current_version=""
            product_name=""
            product_stage=""
            product_latest_version=""
            product_latest_date=""
            stage_product_name=""
            commit_info="$(echo $line| sed -e 's/COMMIT://g')"

            product_latest_commit="$(echo $commit_info | cut -d "|" -f 1)"
            product_latest_date="$(echo $commit_info | cut -d "|" -f 2)"
            product_files=()
        else
            file="$(echo $line| sed -e 's/\://g')"
            c=$(echo $file | grep product.yaml -c)
            # if [ ! $c -gt 0 ]; then
            #     echo "product.yaml: $file, stage_product_name: $stage_product_name"
            # fi
            if [ ! "$product_stage" ]; then
                # Add to $product_stages if new stage
                c=$(echo $file | grep product.yaml -c)
                if [ ! $c -gt 0 ]; then
                    product_stage="$(echo "$file" | cut -d'/' -f3)"
                    if [[ ! " ${product_stages[@]} " =~ " $product_stage " ]]; then
                        product_stages+=("$product_stage")
                    fi
                    if [ "$product_stage" ]; then
                        stage_product_name="$product_name/$product_stage"
                    fi
                fi
            fi
            if [ ! "$product_name" ]; then
                # Add to $product_names if new product
                product_name="$(echo "$file" | cut -d'/' -f2)"
                stage_product_name="$product_name/$product_stage"
                if [[ ! " ${product_names[@]} " =~ " $product_name " ]]; then
                    product_names+=("$product_name")
                fi
            fi
            
            # pre_product_latest_version=$product_latest_version
            # product_latest_version="$(get_latest_version)"
            # if [ ! "$pre_product_latest_version" ] && [ "$product_latest_version" ]; then
            #     
            # fi
            product_info="$(get_product_info)"
            # echo "list(0): product_info: $product_info"
            append_product_files $file
            # echo "list(1): stage_product_name: $stage_product_name, product_files: $product_info_files" 

        fi
    done
    complete_version
    file=""
    
    if [ "$is_smud_gitops_repo" ]; then
        echo ""
    fi

    product_names=($(echo "${product_names[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
    product_stages=($(echo "${product_stages[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

    # echo "product_names: ${product_names[@]}"
    # echo "stages: ${product_stages[@]}"
    # for key in ${!product_infos[@]}; do
    #     echo "p: ${key} ${product_infos[${key}]}"
    # done

    n_products_len=40
    n_current_ver_len=14
    n_latest_ver_len=14
    n_tags_len=10
    for product_stage in ${product_stages[@]}
    do
        printf "\n$product_stage:\n"
        printf "`printf %-${n_products_len}s "PRODUCTS"` `printf %-${n_tags_len}s "TAGS"` `printf %-${n_current_ver_len}s "CURRENT VER."` `printf %-${n_latest_ver_len}s "LATEST VER."` FILES\n"
        for product_name in ${product_names[@]}
        do
            stage_product_name="$product_name/$product_stage"
            product_latest_version=""
            current_version=""
            latest_version=""
            commit=""    
            files=""
            product_info=${product_infos[${stage_product_name}]}
            if [ ! "$product_info" ]; then
                continue
            fi
            if [ "$product_info" ]; then
                current_version="$(echo $product_info | cut -d "|" -f 2)"
                if [ "$new" ] && [ "$current_version" ];then
                    continue
                fi

                # $product_latest_date|$current_version|$product_latest_version|$product_latest_commit|$files
                date="$(echo $product_info | cut -d "|" -f 1)";date="$(date -d "@$date")"
                # latest_version="$(echo $product_info | cut -d "|" -f 3)"
                commit="$(echo $product_info | cut -d "|" -f 4)"
                files="$(echo $product_info | cut -d "|" -f 5)"
                latest_version="$(get_latest_version)"
                # echo "commit: [$commit]"
                # echo "{ stage: '$product_stage',  product_name: '$product_name', latest_version: '$latest_version', commit: '$commit', product_info: '${product_infos[${stage_product_name}]}' }"
                
                tags="$(get_tags "'$current_version'" "'$latest_version'")"
            fi
            
            product_path="products/$product_name"
            stage_filter=":$product_path/$product_stage/** $product_path/product.yaml"

            replace_regex="s/products\/$product_name/./g" 

            print_product_name=`printf %-${n_products_len}s "$product_name"`
            print_current_version=`printf %-${n_current_ver_len}s "$current_version"`
            print_latest_version=`printf %-${n_latest_ver_len}s "$latest_version"`
            print_tags=`printf %-${n_tags_len}s "$tags"`

            printf "$print_product_name $print_tags $print_current_version $print_latest_version $(echo $files | sed -e $replace_regex)\n"
            
        done    
    done
    echo ""
}

get_tags() 
{
    replace_reg_exp="s/'//g"
    cur_ver="$(echo "$1" | sed -e $replace_reg_exp)"
    latest_ver="$(echo "$2" | sed -e $replace_reg_exp)"
    if [ ! "$cur_ver" ] && [ "$latest_ver" ]; then
        echo "NEW"
        return
    elif [ "$cur_ver" ] && [ "$latest_ver" ]; then
        # cur_ver_array=$(echo $cur_ver | tr "." "\n")
        # latest_ver_array=$(echo $latest_ver | tr "." "\n")
        cur_ver_major="$(echo $cur_ver | cut -d "." -f 1)"
        latest_ver_major="$(echo $latest_ver | cut -d "." -f 1)"
        if [ ! "$cur_ver_major" = "$latest_ver_major" ];then
            echo "MAJOR"
            return
        fi
        cur_ver_minor="$(echo $cur_ver | cut -d "." -f 2)"
        latest_ver_minor="$(echo $latest_ver | cut -d "." -f 2)"
        if [ ! "$cur_ver_minor" = "$latest_ver_minor" ];then
            echo "MINOR"
            return
        fi

        cur_ver_patch="$(echo $cur_ver | cut -d "." -f 3)"
        latest_ver_patch="$(echo $latest_ver | cut -d "." -f 3)"
        if [ ! "$cur_ver_patch" = "$latest_ver_patch" ];then
            echo "patch"
            return
        fi
    fi
}

get_product_info() {
    if [ ! "$product_info" ] && [ "$stage_product_name" ]; then
        product_info="${product_infos[${stage_product_name}]}"
    fi
    
    echo "$product_info"
}


create_product_info()
{
    echo "$product_latest_date|$current_version|$product_latest_version|$product_latest_commit|$product_info_files"
}


set_product_info()
{   
    if [ ! "$product_info" ] && [ "$stage_product_name" ]; then    
        product_info="$(get_product_info)"
        if [ ! "$product_info" ]; then
            product_info=${product_infos[${stage_product_name}]}
        fi
    fi

    if [ "$product_info" ] && [ "$stage_product_name" ]; then    
        product_infos[$stage_product_name]=$product_info
    fi
}

get_latest_commit_date()
{
    if [ ! "$product_latest_date" ] && [ "$stage_product_name" ]; then
        product_info="$(get_product_info)"
        if [ "$product_info" ]; then
            product_latest_date="$(echo $product_info | cut -d "|" -f 1)"
        fi
    fi
    echo "$(date -d "@$product_latest_date")"
}

get_current_version()
{
    if [ ! "$current_version" ] && [ "$stage_product_name" ]; then
        product_info="$(get_product_info)"
        if [ "$product_info" ]; then
            current_version="$(echo $product_info | cut -d "|" -f 2)"
        fi
        if [ ! "$current_version" ] ; then
            app_file="products/$stage_product_name/app.yaml"
            if [ -f $app_file ]; then
                current_version=`cat $app_file | grep chartVersion: | cut --delimiter=: -f 2 | xargs | tr -d ['\n','\r'] | cut -f1 --delimiter=# | xargs`
                if [ "$current_version" ]; then
                    set_product_info
                fi
            fi
        fi
    fi
    echo "$current_version"
}

get_latest_version()
{
    if [ ! "$product_latest_version" ] && [ "$stage_product_name" ]; then
        product_info="$(get_product_info)"
        if [ "$product_info" ]; then
            product_latest_version="$(echo $product_info | cut -d "|" -f 3)"
        fi
        if [ ! "$product_latest_version" ] ; then
            if [ ! "$file" ]; then
                file="products/$stage_product_name/app.yaml"
            fi
            if [ ! "$product_latest_commit" ]; then
                product_latest_commit="$(echo $product_info | cut -d "|" -f 4)"
            fi
            c=$(echo $file | grep app.yaml -c)
            if [ $c -gt 0 ] && [ "$product_latest_commit" ]; then
                product_app_content="$(git show $product_latest_commit:$file --diff-filter=ACMRT -- $file)"
                if [ "$product_app_content" ]; then
                    product_latest_version="$(echo "$product_app_content" | grep chartVersion: | cut --delimiter=: -f 2 | xargs | tr -d ['\n','\r'] | cut -f1 --delimiter=#| xargs)"
                    if [ "$product_latest_version" ]; then
                        set_product_info
                    fi
                fi
            fi
        fi
    fi
    echo "$product_latest_version"
}

append_product_files() 
{
    file_to_append="$1"
    if [ ! "$file_to_append" ]; then
        file_to_append=$file
    fi
    if [ ! "$file_to_append" ]; then
        return
    fi

    # echo "file_to_append: $file_to_append"
    if [ ! "$product_info" ] && [ "$stage_product_name" ]; then
        product_info=${product_infos[${stage_product_name}]}
    fi
    if [ "$product_info" ]; then
        product_info_files="$(echo $product_info | cut -d "|" -f 5)"
        old=$product_info_files

        if [ "$product_info_files" ]; then
            c=$(echo $product_info_files | grep $file_to_append -c)

            # echo "c:$c: old:$old"   
            if [ $c -eq 0 ]; then
                product_info_files="$product_info_files $file_to_append"
            fi
        else
            product_info_files="$file_to_append"
        fi

        if [ ! "$old" = "$product_info_files" ]; then
            product_info_files="$(echo $product_info_files|xargs)"
            product_info="$(create_product_info)"
            product_infos[$stage_product_name]=$product_info
        fi
    else
        product_info_files=""
    fi

    # echo "$product_info_files"
}


complete_version()
{
    if [ "$stage_product_name" ]; then
        if [ ! "$product_info" ];then
            product_info="$(get_product_info)"
        fi

        # echo "complete_version(0): $product_info"
        if [ ! "$product_info_files" ]; then
            product_info_files="$(echo $product_info | cut -d "|" -f 5)"
        fi    

        pre_product_latest_version=$product_latest_version
        product_latest_version="$(get_latest_version)"

        # if [ ! "$pre_product_latest_version" ] && [ ! "$product_latest_version" ]; then
            # Adding files information to latest prased product
            current_version="$(get_current_version)"
            product_info="$(create_product_info)"

            product_infos[$stage_product_name]=$product_info

            # echo "complete_version(): { product_name: '$product_name', product_info: '$product_info' }, product_info_files:$product_info_files"
        # fi

    fi
}

