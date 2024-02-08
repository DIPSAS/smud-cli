declare -A product_infos

list()
{
    if [ "$debug" ] && [ "$git_grep" ]; then
        echo "git_grep: $git_grep"
    fi
    if [ "$help" ]; then
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
        gitops_model__show_changes
        return
    fi

    if [ ! "$separator" ] && [ ! "$hide_title" ]; then
        # print title
        if [ "$new" ]; then
            diff_filter='--diff-filter=ACMRT'
            printf "${white}List new products ready for installation:${normal}\n"
        elif [ "$installed" ]; then
          printf "${white}List current products installed:${normal}\n"
        else
            printf "${white}List new or updated products ready for installation:${normal}\n"
        fi    
    fi    
    has_changes_command="git log $git_range --max-count=1 --no-merges --pretty=format:has_commits -- $filter"
    {
        if [ "$git_range" ]; then
            run_command git-log --command-var=has_changes_command --return-var=has_commits --debug-title='Check if any changes'
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
    source=""
    product_name=""
    pos_colon=2
    progress_title="latest products with version"
    if [ "$option" = "installed" ]; then
        progress_title="installed products with version"
        commit_filter=""
        pos_colon=1
        app_files_command="git --no-pager grep 'chartVersion: $version' $commit_filter -- :$app_files_filter|cut -d '#' -f 1|uniq"
    else
        source="git"
        commit_filter="$git_range"
        if [ ! "$commit_filter" ]; then
            return
        fi
        pos_colon=0
        app_files_command="git --no-pager diff $commit_filter --no-merges --pretty=format:'' -- :$filter|grep '+++ .*app.yaml\|+++ .*values.yaml\|+  chartVersion'| sed -e 's/+//g' -e 's/b\///g'|cut -d '#' -f 1"
    fi
    
    {
        run_command --files --command-var=app_files_command --return-var=changed_files --debug-title='Find all changed app files'
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

    app_dependecy_command="git --no-pager grep -B 0 -A 500 'dependencies:' $commit_filter -- :$app_files_filter|sed -e 's/.*:dependencies://g'|uniq"
    run_command --files --command-var=app_dependecy_command --return-var=dependencies_files --skip-error --debug-title='Find all dependencies app files'
    if [ "$dependencies_files" ]; then
        IFS=$'\n';read -rd '' -a dependencies_files <<< "$dependencies_files"
    fi
    if [ "$debug" ]; then
        if [ "$changed_files" ]; then
            print_gray "changed_files:"
            print_gray "${changed_files[@]}"
        fi
        if [ "$dependencies_files" ]; then
            print_gray "dependencies_files:"
            echo "dependencies_files:\n "${dependencies_files[@]}""
        fi
    fi


    progressbar__init $line_numbers 100
    product_info_dependencies=""
    i=0
    for l in "${changed_files[@]}"
    do
        cChartVersion=0
        if [ ! "$l" ];then
            continue
        fi
        line="$(echo "$l"|sed -e 's/[\r\n]//g'|xargs)"
        if [ ! "$line" ];then
            continue
        fi

        c=$(expr match "$line" '.*/app\.yaml')
        c2=$(expr match "$line" '.*/values\.yaml')
        if [ $c -gt 0 ] || [ $c2 -gt 0 ]; then
            i=$((i+1))
            if [ $pos_colon -gt 0 ]; then
                file="$(echo "$line" | cut -d ':' -f $pos_colon)"
            else
                file="$(echo "$line")"
            fi
            product_name="$(echo "$file"  | cut -d '/' -f 2|xargs)"
            product_stage="$(echo "$file" | cut -d '/' -f 3|xargs)"
            stage_product_name="$product_name/$product_stage"
            if [ ! "$source" ]; then
                if [ $pos_colon -gt 0 ]; then
                    cChartVersion=$(echo "$line" | grep ':' -c)
                fi
            fi
        else
            cChartVersion=$(echo "$line" | grep ':' -c)
            file="products/$stage_product_name/app.yaml"
        fi
        
        # echo "$i line=$line, file=$file -- product_name=$product_name, product_stage=$product_stage, stage_product_name=$stage_product_name"
        progressbar__increase $i "${#product_infos[@]} $progress_title found"
        found_version=""
        if [ $cChartVersion -gt 0 ]; then
            found_version="$(echo "$line" | cut -d ':' -f $((pos_colon+2))|xargs|sed -e 's/"//g'|xargs|tr -d ['\n','\r'] |cut -d '#' -f 1 |xargs)"
            # echo "found_version: $found_version -- $line"
        fi
        if [[ ! " ${product_names[@]} " =~ " $product_name " ]]; then
            if [ "$option" = "skip-add-new-product" ]; then
                continue
            fi
            # echo "[$product_name]"
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
        stage_product_name_tmp="$stage_product_name"
        complete_version
        stage_product_name="$stage_product_name_tmp"
    done
    product_name=""
    stage_product_name_tmp=""

    if [ "$dependencies_files" ]; then
        product_info_dependencies=""    
        for line in "${dependencies_files[@]}"
        do
            if [ ! "$line" ];then
                continue
            fi
            c=$(expr match "$line" '.*/app\.yaml') 
            if [ $c -gt 0 ]; then
                file="${line:0:$c}"
                local dependency="${line:$((c+1))}"
                local dependency=$(echo "$dependency"|sed -e 's/\r//g'|xargs)
                
                if [ "$dependency" ] && [ "${dependency:0:1}" = "-" ]; then
                    local dependency="$( echo "${dependency:1}"|sed -e 's/\r//g'|xargs)"
                    product_name="$(echo "$file"  | cut -d '/' -f 2)"
                    product_stage="$(echo "$file" | cut -d '/' -f 3)"
                    local stage_product_name="$product_name/$product_stage"
                    product_info=${product_infos[$stage_product_name]}
                    if [ "$product_info" ];then
                        # echo "stage_product_name: $stage_product_name, dependency: $dependency"
                        append_product_depenencies "$dependency" "$stage_product_name"
                        # echo "depedencies_return: $depedencies_return"
                        product_info=${product_infos[$stage_product_name]}
                        complete_version
                        # echo "xxx: ${product_infos[$stage_product_name]}"
                    fi
                fi
            fi
        done
    fi

    progressbar__end "" "Time to resolve $progress_title took"
    
    product_infos__print_debug
}

product_infos__find_latest_products_with_files()
{
    if [ ! "$show_files" ]; then
        return
    fi

    product_name_files=""
    if [ "$installed" ]; then
        files_command="git ls-files -- $filter $no_app_files_filter"
    else
        if [ ! "$git_range" ]; then
            return
        fi
        
        files_command="git --no-pager log  $git_range --name-only --pretty=  -- :$filter $no_app_files_filter|sort -u"
    fi
    
    {
        run_command changed-files --command-var=files_command --return-var=changed_files --debug-title='Find all changed files'
    } || {
        return
    }
    line_numbers=$(echo "$changed_files" | wc -l)
    IFS=$'\n' read -rd '' -a changed_files <<< "$changed_files"
    # echo "*** find-files :line_numbers: $line_numbers"
    product_yaml_product_names=()
    commit=""

    progressbar__init $line_numbers 100

    i=0
    start_time=$(date +"%Y-%m-%d %H:%M:%S")
    for file in "${changed_files[@]}"
    do
        i=$((i+1))
        # echo "$i: file=$file"
        # exit
        # continue

        product_yaml=$(echo "$file" | grep product.yaml -c)

        product_name_files="$(echo "$file" | cut -d '/' -f 2)"
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

    for product_name_files in "${product_yaml_product_names[@]}"
    do
        for product_stage in "${product_stages[@]}"
        do
            stage_product_name="$product_name_files/$product_stage"
            product_info=${product_infos[${stage_product_name}]}
            if [ ! "$product_info" ]; then
                # echo "** find-files(product.yaml) : file=$file, stage_product_name=$stage_product_name, NO PRODUCT_INFO"     
                continue
            fi

            file="products/$stage_product_name/product.yaml"
            saved_product_name=$product_name_files
            append_product "$file" "A" "false" is_file_appended_stage
            # echo "** find-files(product.yaml) : file=$file, stage_product_name=$stage_product_name, is_file_appended: $is_file_appended_stage"
            complete_version
            product_name_files=$saved_product_name
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
    max_cols=$(echo $(/usr/bin/tput cols))
    n_products_len=40
    n_current_ver_len=14
    n_latest_ver_len=14
    n_tags_len=10
    n_dependencies_len=$((max_len_of_depenencies+2))    
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
        if [ "$product_stage" = "development" ]; then has_development="true"; fi
        if [ "$product_stage" = "internal-test" ]; then has_internal_test="true"; fi
        if [ "$product_stage" = "external-test" ]; then has_external_test="true"; fi
        if [ "$product_stage" = "production" ]; then has_production="true"; fi

        if [ "$prev" = "external-test" ] && [ "$product_stage" = "internal-test" ]; then
            ordered_product_stages[$iPrev]="$product_stage"
            ordered_product_stages[$i]="$prev"
            # echo "set [$iPrev]=$product_stage and [$i]=$prev -- ${ordered_product_stages[@]}"
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
        if [ "$git_range" ]; then
            show_latest_version_in_list="true"
            show_tags_in_list="true"
        fi
        if [ "$is_smud_dev_repo" ]; then
            show_latest_version_in_list=""
            show_tags_in_list=""
        fi
        latest_version_header_text="LATEST VER."

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
            if [ ! "$product_name" ]; then
                continue
            fi
            product_name_list="`echo "$product_name"| sed -e 's/[\r\n]//g'`"
            # product_name_list="$product_name_list"
            stage_product_name="$product_name_list/$product_stage"
            file=""
            product_latest_version=""
            product_latest_commit=""
            current_version=""
            latest_version=""
            commit=""    
            files=""
            local product_dependencies=""
            product_info=${product_infos[${stage_product_name}]}
            if [ ! "$product_info" ]; then
                # echo "Not found : $stage_product_name"
                continue
            fi
            if [ "$product_info" ]; then
                # echo "Found : $stage_product_name"
                product_info__get_current_version product_info current_version
                if [ ! "$current_version" ]; then
                    get_current_version product_info stage_product_name current_version
                    # a=1
                fi    

                if [ "$show_latest_version_in_list" = "true" ]; then
                    product_info__get_latest_version product_info latest_version
                    
                    if [ ! "$latest_version" ] && [ "$git_range" ]; then
                        get_latest_version latest_version
                    fi    
    
                else
                    latest_version=""
                    if [ "$product_stage" = "development" ] && [ "$has_internal_test" ]; then
                        get_next_stage_version "$product_name_list/internal-test" latest_version
                        latest_version_header_text="INT-TEST VER."
                        show_latest_version_in_list="show"
                        show_tags_in_list="show"
                    elif ([ "$product_stage" = "internal-test" ] || [ "$product_stage" = "production" ]) && [ "$has_external_test" ]; then
                        get_next_stage_version "$product_name_list/external-test" latest_version
                        show_latest_version_in_list="show"
                        show_tags_in_list="show"
                        latest_version_header_text="EXT-TEST VER."
                        if [ "$product_stage" = "production" ]; then
                            show_tags_in_list="reverse"
                        fi

                    elif [ "$product_stage" = "external-test" ] && [ "$has_production" ]; then
                        get_next_stage_version "$product_name_list/production" latest_version
                        show_latest_version_in_list="show"
                        show_tags_in_list="show"
                        latest_version_header_text="PROD VER."
                    fi
                fi
                product_info__get_dependencies product_info product_dependencies
                # if [ "$product_dependencies" ]; then
                #     product_dependencies="[$product_dependencies]"
                #     # echo "product_dependencies($stage_product_name): $product_info"
                #     # exit
                # fi

                if [ "$show_files" ]; then
                    product_info__get_latest_files product_info files
                fi
                

                if [ "$new" ] && [ "$current_version" ];then
                    continue
                fi

                # echo "commit: [$commit]"
                # echo "{ stage: '$product_stage',  product_name: '$product_name', latest_version: '$latest_version', commit: '$commit', product_info: '${product_infos[${stage_product_name}]}' }"
                if [ "$show_tags_in_list" ]; then
                    if [ "$show_tags_in_list" = "reverse" ]; then
                        tags="$(get_tags "'$latest_version'" "'$current_version'")"
                    else
                        tags="$(get_tags "'$current_version'" "'$latest_version'")"
                    fi

                    if [ "$major" ] && [ ! "$tags" = "MAJOR" ];then
                        continue
                    fi

                    if [ "$minor" ] && [ ! "$tags" = "MINOR" ];then
                        continue
                    fi

                    if [ "$patch" ] && [ ! "$tags" = "patch" ];then
                        continue
                    fi

                    if [ "$changed" ] && [ ! "$tags" ];then
                        continue
                    fi

                    if [ "$same" ] && [ ! "$tags" = "" ] && [ ! "$current_version" = "$latest_version" ]; then
                        continue
                    fi
                    if [ "$tags" = "MAJOR" ];then iMajor=$((iMajor+1)); fi
                    if [ "$tags" = "MINOR" ];then iMinor=$((iMinor+1)); fi
                    if [ "$tags" = "patch" ];then iPatch=$((iPatch+1)); fi
                    if [ "$tags" = "" ] && [ "$current_version" = "$latest_version" ];then iSame=$((iSame+1)); fi
                    if [ ! "$current_version" ];then iNew=$((iNew+1)); fi
                else
                    if [ "$changed" ];then
                        continue
                    fi
                fi
                iProducts=$((iProducts+1))

            fi
            if [ ! "$printed_stage_label" ]; then
                printf "\n$product_stage:\n"
                printed_stage_label="true"
            fi

            if [ ! "$printed_product_header" ]; then
                files_header=""
                if [ "$show_files" ]; then
                    files_header="FILES" 
                fi

                latest_version_header=""
                if [ "$show_latest_version_in_list" ]; then
                    latest_version_header="`printf %-${n_latest_ver_len}s "$latest_version_header_text"`"
                fi

                tags_header=""
                if [ "$show_tags_in_list" ]; then
                    tags_header="`printf %-${n_tags_len}s "TAGS"`"
                fi
                dependencies_header=""
                if [ $max_len_of_depenencies -gt 0 ]; then
                    dependencies_header="`printf %-${n_dependencies_len}s "DEPENDENCIES"`"
                fi

                printf "`printf %-${n_products_len}s "PRODUCTS"` $tags_header `printf %-${n_current_ver_len}s "CURRENT VER."` $latest_version_header $dependencies_header$files_header\n"
                printed_product_header="true"
            fi

            print_product=$stage_product_name

            product_path="products/$product_name_list"
            stage_filter=":$product_path/$product_stage/** $product_path/product.yaml"

            replace_regex="s/products\/$product_name_list/./g" 

            print_product_name=`printf %-${n_products_len}s "$product_name_list"`
            print_current_version=`printf %-${n_current_ver_len}s "$current_version"`

            print_latest_version=""; 
            if [ "$latest_version_header" ]; then
                print_latest_version=`printf %-${n_latest_ver_len}s "$latest_version"`
            fi

            print_tags=""
            if [ "$tags_header" ]; then
                print_tags=`printf %-${n_tags_len}s "$tags"`
            fi

            print_dependencies=""
            if [ "$dependencies_header" ]; then
                print_dependencies=`printf %-${n_dependencies_len}s "$product_dependencies"`
            fi


            print_files=""; 
            if [ "$files_header" ]; then
                print_files="$(echo "$files" | sed -e $replace_regex)" 
            fi

            print_line="$print_product_name $print_tags $print_current_version $print_latest_version $print_dependencies"
            print_line_full="`echo "$print_line$print_files"| sed -e 's/[\r\n]//g'`"
            # echo "${#line_full} $max_cols"
            if [ ! ${#print_line_full} -gt $max_cols ]; then
                echo "$print_line_full"
            else
                w=$(expr $max_cols - 5)
                # echo "w: $w -- $max_cols"
                printf "${print_line_full:0:$w}...\n"
            fi
            # echo "jepp:$product_name_list"
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
            if [ ! "$silent" ]; then
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
        if [ "$summarize" ] && [ ! "$silent" ]; then
            echo "| Stages:$iStagesTot |TOTAL $summarize"
            echo "=========================================================================================================="
        fi
    fi
    echo ""
}
get_next_stage_version()
{
    local    getnextstageversion__stage_product_name="$1"
    local -n getnextstageversion__next_version="$2"
    local next_product_info=${product_infos[${getnextstageversion__stage_product_name}]}
    get_current_version next_product_info getnextstageversion__stage_product_name getnextstageversion__next_version
    # echo "get_next_stage_version($getnextstageversion__next_version) - [$1,$2]"
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
    local -n getproductinfo__product_info=$1
    if [ "$2" ]; then
        local -n getproductinfo__stage_product_name=$2
    else
        local getproductinfo__stage_product_name="$stage_product_name"
    fi
    if [ ! "$getproductinfo__product_info" ] && [ "$getproductinfo__stage_product_name" ]; then
        getproductinfo__product_info="${product_infos[${getproductinfo__stage_product_name}]}"
    fi
}


create_product_info()
{
    local -n createproductinfo__local_product_info=$1
    createproductinfo__local_product_info="$product_latest_date|$current_version|$product_latest_version|$product_latest_commit|$product_info_files|$product_info_dependencies"
    # echo "create_product_info()...[$product_info_dependencies]"
}


set_product_info()
{   if [ "$1" ]; then
        local -n setproductinfo__product_info=$1
    else
        local setproductinfo__product_info=$product_info
    fi
    if [ "$2" ]; then
        local -n setproductinfo__stage_product_name=$2
    else
        local setproductinfo__stage_product_name=$stage_product_name
    fi

    if [ ! "$setproductinfo__product_info" ] && [ "$setproductinfo__stage_product_name" ]; then    
        get_product_info setproductinfo__product_info setproductinfo__stage_product_name
        if [ ! "$setproductinfo__product_info" ]; then
            setproductinfo__product_info=${product_infos[${setproductinfo__stage_product_name}]}
        fi
    fi

    if [ "$product_info" ] && [ "$stage_product_name" ]; then    
        product_infos[$stage_product_name]=$product_info
    fi
}

get_current_version()
{
    getcurrentversion__product_info=$1
    if [ "$1" ]; then
        local -n getcurrentversion__product_info="$1"
    else
        local getcurrentversion__product_info="$product_info"
    fi
    if [ "$2" ]; then
        local -n getcurrentversion__stage_product_name="$2"
    else
        local getcurrentversion__stage_product_name="$stage_product_name"
    fi

    if [ "$3" ]; then
        local -n getcurrentversion__current_version="$3"
    else
        local getcurrentversion__current_version="$current_version"
    fi

    if [ "$4" ]; then
        local -n getcurrentversion__depedencies="$4"
    else
        local getcurrentversion__depedencies="$product_info_dependencies"
    fi


    if [ ! "$getcurrentversion__current_version" ] && [ "$getcurrentversion__stage_product_name" ]; then
        get_product_info getcurrentversion__product_info getcurrentversion__stage_product_name
        if [ "$getcurrentversion__product_info" ]; then
            product_info__get_current_version getcurrentversion__product_info getcurrentversion__current_version
        fi
        if [ ! "$getcurrentversion__current_version" ] ; then
            local app_file="products/$getcurrentversion__stage_product_name/app.yaml"
            if [ -f $app_file ]; then
                local app_yaml_content="`cat $app_file`"
                getcurrentversion__current_version="`echo "$app_yaml_content" | grep 'chartVersion:' | cut -d ':' -f 2 |xargs|sed -e 's/"//g' -e 's/\r//g' |xargs|tr -d ['\n','\r'] |cut -d '#' -f 1 |xargs`"
                # echo "HIT: [$getcurrentversion__current_version]"
                if [ "$4" ]; then
                    get_depedencies app_yaml_content getcurrentversion__depedencies
                fi    
                if [ "$getcurrentversion__current_version" ]; then
                    current_version="$getcurrentversion__current_version"
                    set_product_info getcurrentversion__product_info getcurrentversion__stage_product_name
                fi
            fi
        fi
    fi

    if [ ! "$3" ]; then
        echo "$getcurrentversion__current_version"
    fi
}

get_depedencies()
{
    local -n getdepedencies__app_yaml_content=$1
    local -n getdepedencies__depedencies=$2
    local getdepedencies__depedencies_arr=()
    local getdepedencies__depedencies="$(echo "$getdepedencies__app_yaml_content" | grep 'dependencies:' -A 500| sed -e 's/dependencies://g')"
    
    if [ ! "$getdepedencies__depedencies" ]; then
        return
    fi
    IFS=$'\n';read -rd '' -a getdepedencies__depedencies_arr <<< "$getdepedencies__depedencies"
    array=()
    for e in "${getdepedencies__depedencies_arr[@]}";
    do
        e="$(echo "$e"|sed -e 's/\r//g'|xargs)"

        local c=$(echo "$e" | grep '-' -c)
        if [ $c -gt 0 ]; then
            e="$( echo "${e:1}" | xargs)"
            array+=("$e")
            # echo "$e -- new product"
        # else
        #     echo "$e"
        fi
    done
    getdepedencies__depedencies="${array[@]}"
    # echo "XXX: $getdepedencies__depedencies"
    l=${#getdepedencies__depedencies}
    if [ $l -gt $max_len_of_depenencies ]; then
        max_len_of_depenencies=$l
    fi

}

get_latest_version()
{
    if [ ! "$product_latest_version" ] && [ "$stage_product_name" ] && [ ! "$is_smud_dev_repo" ]; then
        # echo "stage_product_name: $stage_product_name , file: $file"
        if [ "$1" ]; then
            local -n getlatestversion__latest_version=$1
        else
            getlatestversion__latest_version=""
        fi
        get_product_info product_info stage_product_name
        if [ "$product_info" ]; then
            product_info__get_latest_version product_info getlatestversion__latest_version
            local product_latest_commit_local=$product_latest_commit
            if [ ! "$getlatestversion__latest_version" ]; then
                if [ ! "$file" ]; then
                    file="products/$stage_product_name/app.yaml"
                    c=1
                else   
                    c=$(expr match "$file" '.*/app\.yaml') 
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
                                # run_command --latest-commit --command-var=latest_commit_command --return-var=product_latest_commit --debug-title='Find latest commit'
                            fi
                        } || {
                            return
                        }
                    fi

                    if [ "$product_latest_commit_local" ]; then
                        # echo "**** [$get_latest_version_commit_file]"

                        latest_version_command="git --no-pager grep "chartVersion:" $product_latest_commit_local:$file|cut -d '#' -f 1"
                        {
                            run_command --latest_version --command-var=latest_version_command --return-var=getlatestversion__latest_version --skip-error --debug-title='Find latest versions from conent'
                            # echo "getlatestversion__latest_version(0): '$getlatestversion__latest_version'"
                            getlatestversion__latest_version="$(echo "$getlatestversion__latest_version" | cut -d ':' -f 4 | sed -e 's/"//g'|xargs)"
                            product_latest_version=$getlatestversion__latest_version
                            # echo "getlatestversion__latest_version(1): '$getlatestversion__latest_version'"
                            set_product_info
                        } || {
                            return
                        }
                    fi
                fi
            fi
        fi
    fi
    product_latest_version=$getlatestversion__latest_version
    if [ ! "$1" ]; then
        echo "$product_latest_version"
    fi
}

append_product_files() 
{
    if [ "$3" ];then
        local -n appendproductfiles__return_value=$3
    fi
    appendproductfiles__return_value="false"
    file_to_append="$1"
    if [ ! "$file_to_append" ]; then
        file_to_append=$file
    fi
    if [ ! "$file_to_append" ] || [ ! "$stage_product_name" ]; then
        return 
    fi

    file_state_to_append="$2"
    if [ ! "$file_state_to_append" ]; then
        file_state_to_append=$file_state
    fi

    # echo "file_to_append: $file_to_append ($file_state_to_append) => [$stage_product_name]: '$product_info'"
    local files__product_info="${product_infos[$stage_product_name]}"
    local files__product_info_files=""
    if [ "$files__product_info" ]; then
        product_info__get_latest_files files__product_info files__product_info_files
        old=$files__product_info_files

        if [ "$files__product_info_files" ]; then
            c=$(echo "$files__product_info_files" | grep "$file_to_append" -c)

            # echo "c:$c, old:$old, file_to_append:$file_to_append"   
            if [ "$c" = "0" ]; then
                if [ ! "$file_state_to_append" = "D" ]; then
                    files__product_info_files="$(echo "$files__product_info_files $file_to_append" | xargs)"
                fi    
            elif [ "$file_state_to_append" = "D" ]; then
                replace_regex="s/$(echo "$file_to_append"|sed -e 's/\//\\\//g'|sed -e 's/\./\\\./g' )//g"
                # echo "replace_regex: $replace_regex"
                changed_product_info_files="$(echo "$files__product_info_files" | sed -e $replace_regex | xargs)"
                # echo "files__product_info_files: [$files__product_info_files], changed_product_info_files=[$changed_product_info_files]"
                files__product_info_files=$changed_product_info_files

            fi
        elif [ ! "$file_state_to_append" = "D" ]; then
            files__product_info_files="$file_to_append"
        fi

        if [ ! "$old" = "$files__product_info_files" ]; then
            # echo "¤¤¤ files-pre($stage_product_name): $files__product_info"
            product_info_files="$(echo "$files__product_info_files"|xargs)"
            product_info__get_current_version files__product_info current_version
            product_info__get_latest_version files__product_info product_latest_version
            product_info__get_dependencies files__product_info product_info_dependencies

            create_product_info files__product_info
            # echo "¤¤¤ files-post($stage_product_name): $files__product_info"
            product_infos[$stage_product_name]=$files__product_info  
            appendproductfiles__return_value="true"
        fi
    else
        files__product_info_files=""
    fi
}
max_len_of_depenencies=0
append_product_depenencies() 
{
    if [ ! "$1" ]; then
        return 
    fi
    if [ ! "$2" ]; then
        return 
    fi
    local dependency_to_append="$1"
    local depenency_stage_product_name="$2"
    if [ "$3" ];then
        local -n appendproductdepenencies__return_value=$3
    fi
    appendproductdepenencies__return_value="false"
    local depenency__product_info="${product_infos[$depenency_stage_product_name]}"
    local depenency__product_info_dependencies=""
    if [ "$depenency__product_info" ]; then
        product_info__get_dependencies depenency__product_info depenency__product_info_dependencies
        old=$depenency__product_info_dependencies

        # echo "*** depenency__product_info($depenency_stage_product_name): $depenency__product_info -- depenencies: $depenency__product_info_dependencies"

        if [ "$depenency__product_info_dependencies" ]; then
            c=$(echo "$depenency__product_info_dependencies" | grep "$dependency_to_append" -c)

            # echo "c:$c, old:$old, dependency_to_append:$dependency_to_append"   
            if [ $c -eq 0 ]; then
                depenency__product_info_dependencies="$(echo "$depenency__product_info_dependencies $dependency_to_append" | xargs)"
            fi
        else
            depenency__product_info_dependencies="$dependency_to_append"
        fi

        if [ ! "$old" = "$depenency__product_info_dependencies" ]; then
            product_info_dependencies="$(echo "$depenency__product_info_dependencies"|xargs)"
            l=${#product_info_dependencies}
            if [ $l -gt $max_len_of_depenencies ]; then
                max_len_of_depenencies=$l
            fi
            product_info__get_current_version depenency__product_info current_version
            product_info__get_latest_version depenency__product_info product_latest_version
            product_info__get_latest_files depenency__product_info product_info_files
            create_product_info depenency__product_info
            # echo "### HIT: $product_info_dependencies" 
            # echo "¤¤¤ depenencies($depenency_stage_product_name): $depenency__product_info" 
            product_infos[$depenency_stage_product_name]=$depenency__product_info  
            appendproductdepenencies__return_value="true"
        fi
    else
        depenency__product_info_dependencies=""
    fi
}


append_product()
{
    if [ "$4" ];then
        local -n appendproduct__return_value=$4
    fi

    appendproduct__return_value="false"
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
            appendproduct__return_value="true"
        fi
    fi
    if [ $product_info_created -eq 0 ]; then
        product_info__get_latest_version product_info product_latest_version
        product_info__get_dependencies product_info product_info_dependencies
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

    append_product_files "$file_to_append" "$file_status_to_append" append_product_appendproductfiles__return_value

    # echo "file_to_append: $file_to_append --  product_info=${product_infos[${stage_product_name}]}"
    # exit

    if [ "$appendproduct__return_value" = "false" ]; then
        appendproduct__return_value=$append_product_appendproductfiles__return_value
    fi
}



complete_version()
{
    if [ "$stage_product_name" ]; then
        if [ ! "$product_info" ];then
            get_product_info product_info stage_product_name
        fi

        if [ ! "$product_info" ];then
            create_product_info product_info
        else
            product_info__get_latest_files product_info product_info_files
            product_info__get_latest_version product_info product_latest_version
            product_info__get_current_version product_info current_version
            product_info__get_dependencies product_info product_info_dependencies
            create_product_info product_info
        fi
        # echo "complete_version:"
        # echo "current_version: $current_version"
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
    product_info_dependencies=""

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

# createproductinfo__local_product_info="$product_latest_date|$current_version|$product_latest_version|$product_latest_commit|$product_info_files"
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

product_info__get_dependencies()
{
    # [||||$product_info_files]
    local -n local_product_info=$1
    local -n local_value=$2

    product_info__get_field local_product_info local_value 6
}



