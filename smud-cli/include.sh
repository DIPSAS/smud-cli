#!/usr/bin/env bash

include_main()
{
    print_verbose "**** START: include.sh"
    include_loaded="true"
    white='\033[1;37m' 
    magenta='\x1b[1;m'
    thin_gray='\x1b[22;30m'
    red='\x1b[22;31m'
    green='\x1b[22;32m'
    yellow='\x1b[22;33m'
    blue='\x1b[22;34m'
    magenta_bold='\x1b[22;35m'
    cyan='\x1b[22;36m'
    gray='\x1b[1;90m'
    magenta='\033[38;5;53m'
    bold="$(tput bold)"

    IFS=$'\n'

    # bold="$white"
    normal="$(tput sgr0)"
    reset="$normal"

    p_0="$(echo _0| sed -e 's/_/$/g')"
    p_1="$(echo _1| sed -e 's/_/$/g')"
    p_2="$(echo _2| sed -e 's/_/$/g')"
    print_verbose "**** END: include.sh"
}

exit_if_is_not_a_git_repository() 
{
    if [ ! "$is_repo" ]; then
        msg="Current folder '$(pwd)' is not a git repository!"
        println_not_silent "$msg" $red
        if [ "$1" ];then
            println_not_silent "$1" $red  
        fi
        
        exit 0
    fi
}

contains() {
    test -v "$1" 
    if [ $? -eq 0 ]; then
        local -n contains_list__="$1"
    else
        local contains_list__="$1"
    fi
    
    # if [ ${#contains_list__[@]} -gt 1 ]; then
    #     contains_list__="${contains_list__[@]}"
    # fi
    if [] ! " ${contains_list__[@]} " =~ " (|'"'|"'")$2(|'"'|"'") " ]; then    
        echo 'true'
    fi
    # [[ $contains_list__ =~ (^|[[:space:]])(|'"'|"'")$2(|'"'|"'")($|[[:space:]]) ]] && echo 'true' || echo '' 
}

string_to_array()
{
    local -n string="$1"
    local -n array="$2"
    
    local sep=$'\n'
    if [ "$3" ]; then
        local sep="$3"
    fi
    array=()
    old_SEP=$IFS
    if [ "$sep" = $'\n' ]; then
        IFS=$sep; read -ra array <<< "${string}"
    else
        IFS=$sep; read -a array <<< "${string%%[[:cntrl:]]}"
    fi
    if [ $? -gt 0 ]; then
        echo "ERROR"
    fi
    IFS=$old_SEP
}

fix_print_message()
{
    msg="$(echo "$1"| sed -e 's/%/%%/g')"
    # msg="$(echo "${msg%%[[:cntrl:]]}" | sed -e 's/__nl__/\\n/g')"
    echo "$msg"
}

print()
{
    if [ $# -gt 0 ];then
        msg=`fix_print_message $1`
        printf "$msg\n"
    else
        echo ""
    fi

}

print_color() 
{
    if [ $# -gt 1 ];then
        color="$1"
        shift
        IFS=$'\n'
        msg=`fix_print_message $1`
        printf "$color$msg$normal\n"
    else
        echo ""
    fi
}


print_gray() 
{
    print_color $gray $1
}

print_error() 
{   
    print_color $red "$1"
}

print_debug() 
{
    if [ "$debug" ]; then
        print_color "$gray" "$1"
    fi
}

print_verbose() 
{
    if [ "$verbose" ]; then
        print_gray "$1"
    fi
}

print_not_silent() 
{
    if [ ! "$silent" ] && [ "$1" ]; then
        color="$2"
        msg=`fix_print_message $1`
        msg="$1"
        if [ $color ]; then
            printf "$color$msg$normal $3"
        else
            printf "$msg $3"
        fi
    fi
}

println_not_silent() 
{
    print_not_silent "$1" "$2" $'\n'
}



lower()
{
    local -n str="$1"
    str="$(echo "$str" | tr '[:upper:]' '[:lower:]')"
}

ask()
{
    local -n answer="$1"
    local color="$2"
    local question="$3"
    local skip_newline="$4"
    local default="$5"
    if [ ! "$silent" ] && [ "$skip_newline" != "true" ]; then
        echo ""
    fi
    if [ ! "$silent" ]; then
        if [ "$default" ]; then
            answer=$default
            if [ "$1" = "yes_no" ]; then
                if [ "$default" = "yes" ] || [ "$default" = "y" ] || [ "$default" = "ja" ] || [ "$default" = "j" ]; then        
                    default="Yes"
                elif [ "$answer" = "no" ] || [ "$answer" = "n" ] || [ "$answer" = "nei" ]; then
                    default="No"
                fi
                question=$(sed -e "s/No/No -- Push ENTER to use '$default'/g" <<< "$question")

            fi
        fi
        printf "$color$question $normal"
        read  answer
    fi
    lower answer
    if [ "$1" = "yes_no" ]; then
        if [ "$answer" = "yes" ] || [ "$answer" = "y" ] || [ "$answer" = "ja" ] || [ "$answer" = "j" ]; then
            answer="yes"
        elif [ "$answer" = "no" ] || [ "$answer" = "n" ] || [ "$answer" = "nei" ]; then
            answer="no"
        fi
    fi
    if [ ! "$answer" ] && [ "$default" ]; then
        lower default
        answer=$default
    fi

    if [ ! "$silent" ]; then
        print_debug "You selected: $answer"
    fi
}


progressbar__init()
{
    progressbar__start_time="$(date +"%Y-%m-%d %H:%M:%S")"
    progressbar__last_drawn=0
    progressbar__enable_default_flag="true"
    progressbar__size=$1
    progressbar__enable_size=$2
    progressbar__line_info_enabled="${3:-true}"
    if [ "$no_progress" ]; then
        progressbar__enable_default_flag=""
    fi
    progressbar__enabled=""
    if [ $progressbar__size -gt $progressbar__enable_size ]; then
        progressbar__enabled="$progressbar__enable_default_flag"
    fi

}

progressbar__increase()
{
    progressbar__current=$1
    progressbar__message=$2

    if [ "$progressbar__enabled" ]; then
        diff=$(expr $progressbar__current - $progressbar__last_drawn)
        if [ $diff -lt 5 ]; then
            return
        fi

        simple=""
        progressbar__linmessage=""
        if [ "$progressbar__line_info_enabled" ]; then
            progressbar__linmessage=", (line $progressbar__current/$progressbar__size)"
        fi
        if [ "$simple" ]; then
            print_not_silent "$progressbar__message$progressbar__linmessage"
        else 
            local bar_percentage_value=$((100 * $progressbar__current/$progressbar__size))
            local bar_percentage_chars=$(($bar_percentage_value/2))
            local bar_chars="$(printf %${bar_percentage_chars}s "" | tr ' ' '#')"
            local bar_print="`printf %-50s $bar_chars`"
            local bar_percentage_print="(`printf %-3s $bar_percentage_value`%)"
            if [ ! "$silent" ]; then
                echo -ne "$bar_print  $bar_percentage_print -- $progressbar__message$progressbar__linmessage                    \\r"
            fi
        fi    
        progressbar__last_drawn=$progressbar__current
    fi
}

progressbar__end()
{
    if [ "$progressbar__enabled" ]; then
        local msg=$progressbar__message
        if [ "$1" ]; then
            msg="$1"
        fi
        progressbar__last_drawn=-5
        progressbar__increase $progressbar__size "$msg"
        if [ ! "$silent" ]; then
            echo -ne '\n'
        fi
        progressbar__enabled=""
    fi

    if [ "$2" ] && [ ! "$silent" ]; then
        progressbar__stop_time=$(date +"%Y-%m-%d %H:%M:%S")

        # Calculate and display the time difference
        local start_seconds=$(date -d "$progressbar__start_time" '+%s')
        local stop_seconds=$(date -d "$progressbar__stop_time" '+%s')
        local time_difference=$((stop_seconds - start_seconds))
        echo "$2 $time_difference seconds"
    fi
}

run_command()
{
    declare -A run_command_args
    local command=""
    local command_from_var=""
    local return_in_var=""
    local debug_title=""
    local force_debug_title=""
    local error_code=""
    local skip_error=""
    local skip_shell=""
    local return_array=""
    argument_single_mode="true"
    parse_arguments run_command_args "$@"
    get_arg command_from_var '--command-var,--command-from-var,--command-in-var' '' run_command_args false
    get_arg return_in_var '--return-in-var,--return-var,--return' '' run_command_args false
    get_arg debug_title '--debug-title,-dt' '' run_command_args false
    get_arg force_debug_title '--force-debug-title,-dt' '' run_command_args false
    get_arg error_code '--error-code' '' run_command_args false
    get_arg skip_error '--skip-error,--ignore-error' '' run_command_args false
    get_arg skip_shell '--skip-shell' '' run_command_args false
    get_arg return_array '--return-array,--array' '' run_command_args false
    argument_single_mode=""

    if [ "$command_from_var" ];then
        local -n command="$command_from_var"
    else
        command=""
        get_arg command '--command,-c' '' run_command_args false
    fi


    if [ "$return_in_var" ];then
        local -n run_command_result="$return_in_var"
    else
        local run_command_result=""
    fi
    if [ "$error_code" ];then
        local -n run_command_error_code="$error_code"
    fi

    run_command_error_code=0
    if [ "$return_array" ]; then
        run_command_result=()
    else
        run_command_result=""
    fi


    # echo "command: $command"
    if [ "$verbose" ]; then
        print_debug "run_command(): command_from_var:'$command_from_var'"
        print_debug "run_command(): return_in_var:'$return_in_var'"
        print_debug "run_command(): debug_title: '$debug_title'"
    fi
    if [ ! "$command" ]; then
        print_error "Missing 'command' parameter!"
        return 1
    fi
    if [ "$debug" ] && ([ "$return_in_var" ] || [ "$force_debug_title" ]) ; then
        if [ "$force_debug_title" ]; then
            local debug_title=$force_debug_title
        fi

        if [ ! "$debug_title" ]; then
            local debug_title="Running command"
        fi
        print_debug "$debug_title: [ $normal$command$gray ]"
    fi
    {
        run_command=$command
        if [ "$skip_shell" ]; then
            if [ "$return_array" ]; then
                run_command_result=$(eval $run_command 2>&1)
                run_command_error_code=$?
            else
                run_command_result=$"$(eval $run_command 2>&1)"
                run_command_error_code=$?
            fi
        else
            if [ "$return_array" ]; then
                run_command_result=$(sh -c "$run_command" 2>&1)
                run_command_error_code=$?
            else
                run_command_result=$"$(sh -c "$run_command" 2>&1)"
                run_command_error_code=$?
            fi
        fi
    } || {
        run_command_error_code=$?
        if [ $run_command_error_code -eq 0 ]; then
            run_command_error_code=1
        fi 
    }

    if [ $run_command_error_code -gt 0 ]; then
        if [ ! "$skip_error" ] || [ "$debug" ]; then
            if [ "$return_in_var" ]; then
                print_error "$run_command_result"
            fi
        fi
        return $run_command_error_code
    fi
    if [ ! "$return_in_var" ] && [ "$run_command_result" ];then
        echo "$run_command_result"
    fi
}

setup__product_filters()
{
    if [ "$stages_backup" ]; then
        stage=$stages_backup
    fi
    c=$(echo "$product" | grep ',' -c)
    c1=$(echo "$stage" | grep ',' -c)
    if [ ! $c -eq  0 ] || [ ! $c1 -eq  0 ]; then
        stage="$(echo "$stage"| sed -e 's/ /,/g'|sed -e 's/ //g'| sed -e 's/,,/,/g')"
        IFS=',';read -ra selected_stages <<< "$stage"
        product="$(echo "$product"| sed -e 's/ //g'| sed -e 's/,,/,/g')"
        IFS=',';read -ra selected_products <<< "$product"
        app_files_filter=""
        no_app_files_filter=""
        if [ ! "$1" = "leave_filter_intact" ]; then
            filter=""
            products_filter=""
        fi
        for selected_stage in "${selected_stages[@]}"
        do
            for p in "${selected_products[@]}"
            do
                print_verbose "p: '$p'"
                if [ "$app_files_filter" ];then
                    app_files_filter="$app_files_filter products/$p/$selected_stage/app.yaml"
                    no_app_files_filter="$app_files_filter ^products/$p/$selected_stage/app.yaml"
                else
                    app_files_filter="products/$p/$selected_stage/app.yaml"
                    no_app_files_filter="^products/$p/$selected_stage/app.yaml"
                fi;

                if [ ! "$1" = "leave_filter_intact" ]; then
                    if [ ! "$products_filter" ];then
                        products_filter="products/$p/product.yaml"
                    else
                        products_filter="$products_filter products/$p/product.yaml"
                    fi

                    if [ ! "$filter" ];then
                        filter="products/$p/$selected_stage/** products/$p/product.yaml"
                    else
                        filter="$filter products/$p/$selected_stage/** products/$p/product.yaml"
                    fi
                fi
            done
        done
    else    
        search_product="${product:-**}"
        
        app_files_filter="products/$search_product/$stage/app.yaml"
        no_app_files_filter="^products/$search_product/$stage/app.yaml"
        if [ ! "$1" = "leave_filter_intact" ]; then
            products_filter="products/$search_product/product.yaml"
            filter="products/$search_product/$stage/** products/$search_product/product.yaml"
        fi
    fi
    
    if [ ! "$1" = "leave_filter_intact" ]; then
        filter_=$filter
        filter=":$filter"
        products_filter_=$products_filter
        products_filter=":$products_filter"
    fi

    if [ ! "$stages_backup" ]; then
        stages_backup=$stage
    fi
}

git__setup_source_config()
{
    local local_source_branch=$1
    
    if [ "$is_repo" ]; then
        if [ ! "$local_source_branch" ]; then
            local_source_branch=$source_branch
        fi
        current_branch_escaped=$(sed -e 's/\//.f./g' -e 's/\\/.b./g' <<< "source.$current_branch" )

        if [ ! "$local_source_branch" ]; then
            if [ "$current_branch" ]; then    
                local_source_branch="$(git config --get $current_branch_escaped 2>/dev/null)"
            fi
        fi
        
        if [ ! "$local_source_branch" ]; then
            local_source_branch="upstream/$default_branch"
        fi
        
        old=""
        if [ "$current_branch" ]; then    
            old="$(git config --get $current_branch_escaped 2>/dev/null)"
        fi
        
        if [ ! "$old" = "$local_source_branch" ] || [ ! "$old" ] ; then

            if [ "$old" ] && [ "$current_branch" ]; then
                local dev_null="$(git config --unset-all $current_branch_escaped 2>/dev/null)"
            fi
            
            if [ "$current_branch" ] && [ "$local_source_branch" ]; then
                if [ `grep '/' -c <<< "$local_source_branch"` -eq 0 ]; then
                    local_source_branch="upstream/$local_source_branch"
                fi
                config_source_command="git config --add $current_branch_escaped \"$local_source_branch\" 2>/dev/null"
                run_command --command-from-var=config_source_command --force-debug-title="Set config source.$current_branch" --ignore-error || echo "error"
            fi
        fi
        source_branch=$local_source_branch
    fi

}

git__setup()
{
    from_init_repo_function="$1"
    # print_debug "git__setup(): [ default_branch='$default_branch', current_branch='$current_branch', from_init_repo_function='$from_init_repo_function' ]"
    if [ ! "$default_branch" ]; then
        default_branch="$(git config --get default.branch)"
        if [ ! "$default_branch" ]; then
            default_branch="$(git config --list | grep -E 'branch.(main|master).remote' | sed -e 's/branch\.//g' -e 's/\.remote//g' -e 's/=origin//g')"
            if [ ! "$default_branch" ]; then
                default_branch="$(git config --get init.defaultbranch)"
            fi

            if [ ! "$default_branch" ]; then
                default_branch="main"
            fi

            can_do_git="$(git branch --list $default_branch)"
            if [ "$default_branch" ]; then
                local dev_null="$(git config --add default.branch $default_branch)"
            fi
        fi
        # print_debug "git__setup(): [ default_branch='$default_branch' ]"
    else
        old="$(git config --get default.branch)"
        if [ "$old" ]; then
            local dev_null="$(git config --unset default.branch)"
       fi
       local dev_null="$(git config --add default.branch $default_branch)"
    fi
    current_branch="$(git branch --show-current)"
    if [ ! "$current_branch" ]; then
        current_branch="$default_branch"
    fi

    if [ ! "$upstream_url" ]; then
        upstream_url="$(git config --get remote.upstream.url)"
    fi

    # print_debug "git__setup(): [ default_branch='$default_branch',  current_branch='$current_branch', upstream_url='$upstream_url' ]"

    git__setup_source_config

    if [ ! "$from_commit" ] && [ ! "$from_date" ] && [ "$current_branch" ] ; then
        from_commit_command="git rev-list $current_branch -1 2>/dev/null"
        {
            run_command from-commit --command-var from_commit_command --return-var from_commit --skip-error --debug-title "from-commit-command"
        } || {
            if [ "$from_init_repo_function" != "true" ]; then
                if [ "$command" = "init" ]; then
                    return
                fi

                printf "${red}No commits found in branch '$current_branch', run ${gray}smud init ${red} to fetch the upstream repository. -- $command\n${normal}"
                exit
            fi
        }
    fi

    if [ ! "$to_commit" ] && [ ! "$is_smud_dev_repo" ] && [ "$source_branch" ];then
        if [ "$upstream_url" ] || [ ! "$source_branch" = "upstream/$default_branch" ]; then
            to_commit_command="git rev-list $source_branch -1 2>/dev/null"
            run_command to-commit --command-var to_commit_command --return-var to_commit --skip-error --debug-title "to-commit-command"
        fi
    fi
    
    if [ "$from_commit$to_commit" ]; then
        commit_range="$from_commit..$to_commit"
    fi
    if [ "$from_date" ]; then
        commit_range="$to_commit.."
        date_range="--since '$(echo "$from_date"| sed -E 's/( |_)/./g')'" 
    fi
    if [ "$to_date" ]; then
        date_range="$date_range --before '$(echo "$to_date"| sed -E 's/( |_)/./g')'" 
    fi
    if [ "$version" ]; then
        git_grep_version="-GchartVersion:.$version"
        git_grep="$(echo "$git_grep $git_grep_version" | xargs)"
    fi
}

if [ ! "$include_loaded" ]; then
    curr_dir="$(pwd)"
    namespace_filter="-A"
    
    include_main
fi