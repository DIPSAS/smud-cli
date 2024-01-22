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

    init

    if [ ! "$is_repo" ]; then
        printf "${red}'$(pwd)' is not a git repository! ${normal}\n"
        return
    fi

    if [ ! "$product" ] && [ ! "$installed" ]; then
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
    has_changes_command="git log $git_range --max-count=1 --no-merges --pretty=format:has_commits -- $filter"
    {
        if [ "$git_range" ]; then
            run_command git-log --command-from-var=has_changes_command --return-in-var=has_commits --debug-title='Check if any changes'
        fi    
        if [ ! "$has_commits" ]; then
            if [ ! "$is_smud_dev_repo" ] && [ ! "$installed" ]; then
                printf "${gray}No products found.${normal}\n"   
                return 
            fi
        fi
    } || {
        return
    }

    if [ "$installed" ]; then
        product_infos__find_latest_products_with_version "installed"
        product_infos__find_latest_products_with_version "skip-add-new-product"
    else
        product_infos__find_latest_products_with_version 
    fi

    product_infos__find_latest_products_with_files
    
    product_infos__print
}

product_infos__find_latest_products_with_version()
{
    option="$1"

    product_name=""
    commit_filter="$to_commit"
    pos_colon=2
    progress_title="latest products with version"
    if [ "$option" = "installed" ]; then
        progress_title="installed products with version"
        commit_filter=""
        pos_colon=1
    else
        if [ ! "$commit_filter" ]; then
            return
        fi
    fi
    files_command="git --no-pager grep chartVersion $commit_filter -- :$app_files_filter"
    {
        run_command --files --command-from-var=files_command --return-in-var=changed_files --debug-title='Find all changed files'
    } || {
        return
    }
    line_numbers=$(echo "$changed_files" | wc -l)
    IFS=$'\n' read -rd '' -a changed_files <<< "$changed_files"
    # echo "line_numbers: $line_numbers"

    if [ ! "$product_stages" ]; then
        product_stages=()
    fi

    if [ ! "$product_names" ]; then
        product_names=()
    fi

    progressbar__init $line_numbers 50

    i=0
    for line in "${changed_files[@]}"
    do
        i=$((i+1))
        # echo "$i: line=$line"

        progressbar__increase $i "${#product_infos[@]} $progress_title found"

        file="$(echo "$line" | cut -d ':' -f $pos_colon)"
        product_name="$(echo "$file"  | cut -d '/' -f 2)"
        product_stage="$(echo "$file" | cut -d '/' -f 3)"
        stage_product_name="$product_name/$product_stage"
        found_version="$(echo "$line" | cut -d ':' -f $((pos_colon+2))|xargs|sed -e 's/"//g'|xargs|tr -d ['\n','\r'] |cut -d '#' -f 1 |xargs)"
        if [[ ! " ${product_names[@]} " =~ " $product_name " ]]; then
            if [ "$option" = "skip-add-new-product" ]; then
                continue
            fi
            product_names+=("$product_name")
        fi

        if [[ ! " ${product_stages[@]} " =~ " $product_stage " ]]; then
            if [ "$option" = "skip-add-new-product" ]; then
                continue
            fi
            product_stages+=("$product_stage")
        fi

        if [ "$option" ]; then
            product_info=${product_infos[${stage_product_name}]}
        fi

        if [ "$option" = "skip-add-new-product" ] && [ ! "$product_info" ]; then
            continue
        fi

        if [ ! "$option" = "installed" ]; then
            product_latest_version=$found_version
            if [ "$option" ]; then
                product_info__get_current_version product_info current_version
            fi
        else
            current_version=$found_version
            product_info__get_latest_version product_info product_latest_version
        fi

        add_product="true"
        if [ "$option" = "skip-add-new-product" ]; then
            add_product="false"
        fi

        # echo "*** option: $option :: $i: file=$file, stage_product_name=$stage_product_name, found_version=$found_version,  product_latest_version=$product_latest_version, current_version=$current_version, add_product: $add_product"

        append_product "$file" "A" "$add_product"
        complete_version
    done

    progressbar__end "" "Time to resolve $progress_title took"
    
    product_infos__print_debug
}

product_infos__find_latest_products_with_files()
{
    if [ "$skip_files" ]; then
        return
    fi
    product_name=""
    if [ "$installed" ]; then
        files_command="git ls-files -- $filter $no_app_files_filter"
    else
        if [ ! "$git_range" ]; then
            return
        fi
        files_command="git diff-tree $git_range $diff_filter  --reverse --no-merges --name-only -r -- :$filter $no_app_files_filter"
    fi
    
    {
        run_command diff-tree --command-from-var=files_command --return-in-var=changed_files --debug-title='Find all latest changed files'
    } || {
        return
    }
    line_numbers=$(echo "$changed_files" | wc -l)
    IFS=$'\n' read -rd '' -a changed_files <<< "$changed_files"
    # echo "*** find-files :line_numbers: $line_numbers"
    product_yaml_product_names=()
    commit=""

    progressbar__init $line_numbers 50

    i=0
    start_time=$(date +"%Y-%m-%d %H:%M:%S")
    for file in "${changed_files[@]}"
    do
        i=$((i+1))
        # echo "$i: file=$file"
        # exit
        # continue

        product_yaml=$(echo "$file" | grep product.yaml -c)

        product_name="$(echo "$file" | cut -d '/' -f 2)"
        if [ $product_yaml -eq 0 ]; then
            # Add to $product_stages if new stage
            product_stage="$(echo "$file" | cut -d '/' -f 3)"
        fi

        if [ $product_yaml -eq 1 ]; then
            if [[ ! " ${product_yaml_product_names[@]} " =~ " $product_name " ]]; then
                product_yaml_product_names+=("$product_name")
            fi
            continue
        fi

        stage_product_name="$product_name/$product_stage"
        product_info=${product_infos[${stage_product_name}]}
        if [ ! "$product_info" ]; then
            # echo "** find-files : $i: file=$file, stage_product_name=$stage_product_name, NO PRODUCT_INFO"     
            continue
        fi

        append_product "$file" "A" "false" is_file_appended
        # echo "** find-files : $i: file=$file, stage_product_name=$stage_product_name, product_latest_version=$product_latest_version, current_version=$current_version, is_file_appended: $is_file_appended"
        complete_version

        progressbar__increase $i "${#product_infos[@]} products updated with files"
    done

    for product_name in "${product_yaml_product_names[@]}"
    do
        for product_stage in "${product_stages[@]}"
        do
            stage_product_name="$product_name/$product_stage"
            product_info=${product_infos[${stage_product_name}]}
            if [ ! "$product_info" ]; then
                # echo "** find-files(product.yaml) : file=$file, stage_product_name=$stage_product_name, NO PRODUCT_INFO"     
                continue
            fi

            file="products/$stage_product_name/product.yaml"
            saved_product_name=$product_name
            append_product "$file" "A" "false" is_file_appended_stage
            # echo "** find-files(product.yaml) : file=$file, stage_product_name=$stage_product_name, is_file_appended: $is_file_appended_stage"
            complete_version
            product_name=$saved_product_name
        done
    done


    progressbar__end "" "Time to update latest products with files took"

    product_infos__print_debug
}

product_infos__print_debug()
{
    # product_names=($(echo "${product_names[@]}" | tr ' ' $'\n' | sort -u | tr $'\n' ' '))
    # product_stages=($(echo "${product_stages[@]}" | tr ' ' $'\n' | sort -u | tr $'\n' ' '))
    if [ "$verbose" ]; then
        echo "product_names: ${product_names[@]}"
        echo "stages: ${product_stages[@]}"
        for key in ${!product_infos[@]}; do
            echo "p: ${key}={${product_infos[${key}]}}"
        done
    fi
}

product_infos__print()
{
    n_products_len=40
    n_current_ver_len=14
    n_latest_ver_len=14
    n_tags_len=10
    printed_product=""
    iMajorTot=0
    iMinorTot=0
    iNewTot=0
    iPatchTot=0
    iSameTot=0
    iProductsTot=0
    iStagesTot=0

    # reorder product_stages-array: [development, internal-test, extaranl-test]
    i=0
    iPrev=0
    ordered_product_stages=()
    # echo "HIT ${product_stages[@]}"
    for product_stage in "${product_stages[@]}"
    do
        if [ "$prev" = "external-test" ] && [ "$product_stage" = "internal-test" ]; then
            ordered_product_stages[$iPrev]="$product_stage"
            ordered_product_stages[$i]="$prev"
            echo "set [$iPrev]=$product_stage and [$i]=$prev -- ${ordered_product_stages[@]}"
        else
            ordered_product_stages[$i]=$product_stage
        fi
        prev=$product_stage
        iPrev=$i
        i=$((i+1))
    done

    for product_stage in "${ordered_product_stages[@]}"
    do
        # echo "hit:$product_stage"
        printed_stage_label=""
        printed_product_header=""
        iMajor=0
        iMinor=0
        iNew=0
        iPatch=0
        iSame=0
        iProducts=0
        for product_name in "${product_names[@]}"
        do
            stage_product_name="$product_name/$product_stage"
            file=""
            # echo "hit:$stage_product_name"
            product_latest_version=""
            product_latest_commit=""
            current_version=""
            latest_version=""
            commit=""    
            files=""
            product_info=${product_infos[${stage_product_name}]}
            if [ ! "$product_info" ]; then
                # echo "Not found : $stage_product_name"
                continue
            fi
            if [ "$product_info" ]; then
                # echo "Found : $stage_product_name"
                product_info__get_latest_version product_info latest_version
                
                if [ ! "$latest_version" ] && [ "$git_range" ]; then
                    get_latest_version latest_version
                fi    
                product_info__get_current_version product_info current_version
                if [ ! "$current_version" ]; then
                    current_version="$(get_current_version)"
                fi    

                if [ ! "$skip_files" ]; then
                    product_info__get_latest_files product_info files
                fi


                if [ "$new" ] && [ "$current_version" ];then
                    continue
                fi

                # echo "commit: [$commit]"
                # echo "{ stage: '$product_stage',  product_name: '$product_name', latest_version: '$latest_version', commit: '$commit', product_info: '${product_infos[${stage_product_name}]}' }"
                
                tags="$(get_tags "'$current_version'" "'$latest_version'")"

                if [ "$major" ] && [ ! "$tags" = "MAJOR" ];then
                    continue
                fi

                if [ "$minor" ] && [ ! "$tags" = "MINOR" ];then
                    continue
                fi

                if [ "$patch" ] && [ ! "$tags" = "patch" ];then
                    continue
                fi

                if [ "$same" ] && [ ! "$tags" = "" ] && [ ! "$current_version" = "$latest_version" ]; then
                    continue
                fi
                iProducts=$((iProducts+1))
                if [ "$tags" = "MAJOR" ];then iMajor=$((iMajor+1)); fi
                if [ "$tags" = "MINOR" ];then iMinor=$((iMinor+1)); fi
                if [ "$tags" = "patch" ];then iPatch=$((iPatch+1)); fi
                if [ "$tags" = "" ] && [ "$current_version" = "$latest_version" ];then iSame=$((iSame+1)); fi
                if [ ! "$current_version" ];then iNew=$((iNew+1)); fi
            fi
            if [ ! "$printed_stage_label" ]; then
                printf "\n$product_stage:\n"
                printed_stage_label="true"
            fi

            if [ ! "$printed_product_header" ]; then
                files_header=""
                if [ ! "$skip_files" ]; then
                    files_header="FILES" 
                fi

                latest_version_header=""
                if [ "$git_range" ]; then
                    latest_version_header="`printf %-${n_latest_ver_len}s "LATEST VER."`"
                fi

                printf "`printf %-${n_products_len}s "PRODUCTS"` `printf %-${n_tags_len}s "TAGS"` `printf %-${n_current_ver_len}s "CURRENT VER."` $latest_version_header $files_header\n"
                printed_product_header="true"
            fi

            print_product=$stage_product_name

            product_path="products/$product_name"
            stage_filter=":$product_path/$product_stage/** $product_path/product.yaml"

            replace_regex="s/products\/$product_name/./g" 

            print_product_name=`printf %-${n_products_len}s "$product_name"`
            print_current_version=`printf %-${n_current_ver_len}s "$current_version"`
            print_tags=`printf %-${n_tags_len}s "$tags"`

            print_latest_version=""; 
            if [ "$latest_version_header" ]; then
                print_latest_version=`printf %-${n_latest_ver_len}s "$latest_version"`
            fi

            print_files=""; 
            if [ "$files_header" ]; then
                print_files="$(echo "$files" | sed -e $replace_regex)" 
            fi

            printf "$print_product_name $print_tags $print_current_version $print_latest_version $print_files\n"
        done  
        summarize=""
        if [ $iProducts -gt 0 ];then summarize="${summarize} Products:$iProducts |"; fi
        if [ $iMajor -gt 0 ];then summarize="${summarize} Majors:$iMajor |"; fi
        if [ $iMinor -gt 0 ];then summarize="${summarize} Minors:$iMinor |"; fi
        if [ $iPatch -gt 0 ];then summarize="${summarize} Patches:$iPatch |"; fi
        if [ $iSame -gt 0 ];then summarize="${summarize} Same versions:$iSame |"; fi
        if [ $iNew -gt 0 ];then summarize="${summarize} New versions:$iNew |"; fi
        if [ "$summarize" ]; then
            echo "----------------------------------------------------------------------------------------------------------"
            echo "| Stage:$product_stage |$summarize"
            iProductsTot=$((iProductsTot+iProducts))
            iMajorTot=$((iMajorTot+iMajor))
            iMinorTot=$((iMinorTot+iMinor))
            iPatchTot=$((iPatchTot+iPatch))
            iSameTot=$((iSameTot+iSame))
            iNewTot=$((iNewTot+iNew))
            iStagesTot=$((iStagesTot+1))
            echo "=========================================================================================================="
        fi
    done
    if [ ! "$print_product" ]; then
        printf "${gray}No products found by filter.${normal}\n"   
        product_stages=()
        product_infos=()
    else
        summarize=""
        if [ $iProductsTot -gt 0 ];then summarize="${summarize} Products:$iProductsTot |"; fi
        if [ $iMajorTot -gt 0 ];then summarize="${summarize} Majors:$iMajorTot |"; fi
        if [ $iMinorTot -gt 0 ];then summarize="${summarize} Minors:$iMinorTot |"; fi
        if [ $iPatchTot -gt 0 ];then summarize="${summarize} Patches:$iPatchTot |"; fi
        if [ $iSameTot -gt 0 ];then summarize="${summarize} Same versions:$iSameTot |"; fi
        if [ $iNewTot -gt 0 ];then summarize="${summarize} New versions:$iNewTot |"; fi
        if [ "$summarize" ]; then
            echo "| Stages:$iStagesTot |TOTAL $summarize"
            echo "=========================================================================================================="
        fi
    fi
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
        # cur_ver_array=$(echo "$cur_ver" | tr "." "\n")
        # latest_ver_array=$(echo "$latest_ver" | tr "." "\n")
        cur_ver_major="$(echo "$cur_ver" | cut -d "." -f 1)"
        latest_ver_major="$(echo "$latest_ver" | cut -d "." -f 1)"
        if [ ! "$cur_ver_major" = "$latest_ver_major" ];then
            echo "MAJOR"
            return
        fi
        cur_ver_minor="$(echo "$cur_ver" | cut -d "." -f 2)"
        latest_ver_minor="$(echo "$latest_ver" | cut -d "." -f 2)"
        if [ ! "$cur_ver_minor" = "$latest_ver_minor" ];then
            echo "MINOR"
            return
        fi

        cur_ver_patch="$(echo "$cur_ver" | cut -d "." -f 3)"
        latest_ver_patch="$(echo "$latest_ver" | cut -d "." -f 3)"
        if [ ! "$cur_ver_patch" = "$latest_ver_patch" ];then
            echo "patch"
            return
        fi
    fi
}

get_product_info() {
    local -n get_product_info__local_product_info=$1
    if [ ! "$get_product_info__local_product_info" ] && [ "$stage_product_name" ]; then
        get_product_info__local_product_info="${product_infos[${stage_product_name}]}"
    fi
}


create_product_info()
{
    local -n create_product_info__local_product_info=$1
    create_product_info__local_product_info="$product_latest_date|$current_version|$product_latest_version|$product_latest_commit|$product_info_files"
}


set_product_info()
{   
    if [ ! "$product_info" ] && [ "$stage_product_name" ]; then    
        get_product_info product_info
        if [ ! "$product_info" ]; then
            product_info=${product_infos[${stage_product_name}]}
        fi
    fi

    if [ "$product_info" ] && [ "$stage_product_name" ]; then    
        product_infos[$stage_product_name]=$product_info
    fi
}

get_current_version()
{
    if [ ! "$current_version" ] && [ "$stage_product_name" ]; then
        get_product_info product_info
        if [ "$product_info" ]; then
            product_info__get_current_version product_info current_version
        fi
        if [ ! "$current_version" ] ; then
            app_file="products/$stage_product_name/app.yaml"
            if [ -f $app_file ]; then
                current_version=`cat $app_file | grep chartVersion: | cut -d ':' -f 2 |xargs|sed -e 's/"//g'|xargs|tr -d ['\n','\r'] |cut -d '#' -f 1 |xargs`
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
        # echo "stage_product_name: $stage_product_name , file: $file"
        if [ "$1" ]; then
            local -n product_latest_version_local=$1
        else
            product_latest_version_local=""
        fi
        get_product_info product_info
        if [ "$product_info" ]; then
            product_info__get_latest_version product_info product_latest_version_local
            local product_latest_commit_local=$product_latest_commit
            if [ ! "$product_latest_version_local" ]; then
                if [ ! "$file" ]; then
                    file="products/$stage_product_name/app.yaml"
                    c=1
                else   
                    c=$(expr match $file '.*/app\.yaml') 
                fi
                                  
                if [ $c -gt 0 ]; then
                    if [ ! "$product_latest_commit_local" ]; then
                        product_info__get_latest_commit product_info product_latest_commit_local
                    fi
                    if [ ! "$product_latest_commit_local" ]; then
                        {   
                            # echo "hit:$git_range"
                            if [ "$git_range" ]; then
                                product_latest_commit_local="\$(git log $git_range --diff-filter=ACMRTUB --max-count=1 --pretty=format:%H -- :$file)"
                                # run_command --latest-commit --command-from-var=latest_commit_command --return-in-var=product_latest_commit --debug-title='Find latest commit'
                            fi
                        } || {
                            return
                        }
                    fi

                    if [ "$product_latest_commit_local" ]; then
                        # echo "**** [$get_latest_version_commit_file]"

                        latest_version_command="git --no-pager grep "chartVersion:" $product_latest_commit_local:$file"
                        {
                            run_command --latest_version --command-from-var=latest_version_command --return-in-var=product_latest_version_local --debug-title='Find latest versions from conent'
                            # echo "product_latest_version_local(0): '$product_latest_version_local'"
                            product_latest_version_local="$(echo "$product_latest_version_local" | cut -d ':' -f 4 | sed -e 's/"//g'|xargs)"
                            product_latest_version=$product_latest_version_local
                            # echo "product_latest_version_local(1): '$product_latest_version_local'"
                            set_product_info
                        } || {
                            return
                        }
                    fi
                fi
            fi
        fi
    fi
    product_latest_version=$product_latest_version_local
    if [ ! "$1" ]; then
        echo "$product_latest_version"
    fi
}

append_product_files() 
{
    if [ "$3" ];then
        local -n append_product_files_return_value=$3
    fi
    append_product_files_return_value="false"
    file_to_append="$1"
    if [ ! "$file_to_append" ]; then
        file_to_append=$file
    fi
    if [ ! "$file_to_append" ]; then
        return 
    fi

    file_state_to_append="$2"
    if [ ! "$file_state_to_append" ]; then
        file_state_to_append=$file_state
    fi

    # echo "file_to_append: $file_to_append ($file_state_to_append) => [$stage_product_name]: '$product_info'"
    if [ "$product_info" ]; then
        product_info__get_latest_files product_info product_info_files
        old=$product_info_files

        if [ "$product_info_files" ]; then
            c=$(echo "$product_info_files" | grep $file_to_append -c)

            # echo "c:$c, old:$old, file_to_append:$file_to_append"   
            if [ $c -eq 0 ]; then
                if [ ! "$file_state_to_append" = "D" ]; then
                    product_info_files="$(echo "$product_info_files $file_to_append" | xargs)"
                fi    
            elif [ "$file_state_to_append" = "D" ]; then
                replace_regex="s/$(echo "$file_to_append"|sed -e 's/\//\\\//g'|sed -e 's/\./\\\./g' )//g"
                # echo "replace_regex: $replace_regex"
                changed_product_info_files="$(echo "$product_info_files" | sed -e $replace_regex | xargs)"
                # echo "product_info_files: [$product_info_files], changed_product_info_files=[$changed_product_info_files]"
                product_info_files=$changed_product_info_files

            fi
        elif [ ! "$file_state_to_append" = "D" ]; then
            product_info_files="$file_to_append"
        fi

        if [ ! "$old" = "$product_info_files" ]; then
            product_info_files="$(echo "$product_info_files"|xargs)"
            create_product_info product_info
            product_infos[$stage_product_name]=$product_info  
            append_product_files_return_value="true"
        fi
    else
        product_info_files=""
    fi
}

append_product()
{
    if [ "$4" ];then
        local -n append_product_return_value=$4
    fi

    append_product_return_value="false"
    local product_info_created=0
    if [ ! "$product_info" ] && [ "$stage_product_name" ]; then
        product_info=${product_infos[${stage_product_name}]}
        if [ ! "$product_info" ];then
            if [ "$3" = "false" ];then
                return 
            fi    
            product_info_created=1
            create_product_info product_info
            product_infos[$stage_product_name]=$product_info        
            append_product_return_value="true"
        fi
    fi
    if [ $product_info_created -eq 0 ]; then
        product_info__get_latest_version product_info product_latest_version
    fi

    file_to_append="$1"

    if [ ! "$file_to_append" ]; then
        return 
    fi

    file_state_to_append="$2"
    if [ ! "$file_state_to_append" ]; then
        file_state_to_append=$file_state
    fi

    if [ ! "$file_state_to_append" ]; then
        file_state_to_append="A"
    fi

    append_product_files "$file_to_append" "$file_status_to_append" append_product_append_product_files_return_value

    if [ "$append_product_return_value" = "false" ]; then
        append_product_return_value=$append_product_append_product_files_return_value
    fi
}



complete_version()
{
    if [ "$stage_product_name" ]; then
        if [ ! "$product_info" ];then
            get_product_info product_info
        fi

        if [ ! "$product_info" ];then
            create_product_info product_info
        else
            product_info__get_latest_files product_info product_info_files
            product_info__get_latest_version product_info product_latest_version
            product_info__get_current_version product_info current_version
            create_product_info product_info
        fi

        product_infos[$stage_product_name]=$product_info        
        if [ "$1" ]; then
            echo "complete_version(): product_name: '$product_name', current_version: '$current_version' , product_info_files:$product_info_files, product_info: '$product_info' }"
        fi

    fi

    file_state=""
    file=""
    product_info=""
    product_info_files=""
    current_version=""
    product_name=""
    product_stage=""
    product_latest_version=""
    product_latest_date=""
    stage_product_name=""

}


product_info__get_field()
{
    # [1:$product_latest_date|2:$current_version|3:$product_latest_version|4:$product_latest_commit|5:$product_info_files]

    local -n local_field_product_info=$1
    local -n local_field_value=$2
    local local_field_index=$3

    get_product_info local_field_product_info

    if [ "$local_field_product_info" ] && [ ! "$local_field_value" ]; then
        local_field_value="$(echo "$local_field_product_info" | cut -d "|" -f $local_field_index)"
    fi
}

product_info__get_latest_commit_date()
{
    # [product_latest_date||||]
    local -n local_product_info=$1
    local -n local_value=$2
    
    product_info__get_field local_product_info local_value 1
}

# create_product_info__local_product_info="$product_latest_date|$current_version|$product_latest_version|$product_latest_commit|$product_info_files"
product_info__get_current_version()
{
    # [|$current_version|||]
    local -n local_product_info=$1
    local -n local_value=$2

    product_info__get_field local_product_info local_value 2
}

product_info__get_latest_version()
{
    # [||$product_latest_version||]
    local -n local_product_info=$1
    local -n local_value=$2

    product_info__get_field local_product_info local_value 3
}

product_info__get_latest_commit()
{
    # [|||$product_latest_commit|]
    local -n local_product_info=$1
    local -n local_value=$2

    product_info__get_field local_product_info local_value 4
}

product_info__get_latest_files()
{
    # [||||$product_info_files]
    local -n local_product_info=$1
    local -n local_value=$2

    product_info__get_field local_product_info local_value 5
}



