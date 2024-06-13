#!/usr/bin/env bash

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


declare -A ARGS

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
    if [[ ! " ${contains_list__[@]} " =~ " (|'"'|"'")$2(|'"'|"'") " ]]; then    
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

parse_arguments()
{   
    local old_SEP=$IFS
    local -n parse_arguments_args="$1"
    # echo "0.str: $@"
    if [ $# -gt 0 ];then
        has_args="true"
        local str="$(echo " $@"|sed -e 's/--/-_sep_/g' |sed -e 's/ -/§/g')"
        # echo "str: $str"
        IFS="§"; read -ra array <<< " $str";
        local c=$(echo "${array[0]}" | grep '-' -c)
        if [ $c -eq 0 ]; then
            shift
            if [ $# -eq 0 ];then
                IFS=$old_SEP
                return
            fi
            local str="$(echo " $@"|sed -e 's/--/-_sep_/g' |sed -e 's/ -/§/g')"
            # echo "str: $str"
            IFS="§"; read -ra array <<< " $str";
        fi
        # echo "str: $str"
        # echo "array: ${array[@]}"
        for s in "${array[@]}"
        do
            # echo "0:s: $s"
            if [ ! "$s" ] || [ "$s" = " " ]; then
                continue
            fi
            local s="$(echo "$s"|xargs -d ' '| tr -d '\n')"
            # echo "s: $s"
            local s="$(echo "-$s" |sed -e 's/_sep_/-/g')"
            # echo "s: $s"
            arg=()
            if [ $(grep '=' -c <<< $s) -gt 0 ]; then
                IFS='='; read -ra arg <<< "$s"
                # echo "eq.arg: { key: ${arg[0]}, value: ${arg[1]} }"
            else
                IFS=' '; read -ra arg_ <<< "$s"
                arg[0]="${arg_[0]}"
                arg[1]="${arg_[@]:1}"
                # echo "space.arg: { key: ${arg[0]}, value: ${arg[1]} }"
            fi
            # echo "%%%  ${arg[@]}"

            local key="${arg[0]}"
            # echo "key: $key"
            if [ ! "$key" = "-n" ]; then
                local key="$(echo "${arg[0]}"|xargs -d ' '| tr -d '\n')"
            fi
            local value="${arg[1]}"
            # echo "key: $key, value: $value"

            if [ ! "$value" ]; then
                local c=$(echo "$s" | grep ' ' -c)
                if [ $c -gt 0 ]; then
                    IFS=' ';read -ra arg <<< "$s"
                    local key="$(echo "${arg[0]}")"
                    local value="$(echo "$s"|sed -e "s/$key //g"|xargs -d ' '| tr -d '\n')"
                fi
            fi
            local value="${value:-true}"
            if [ "$key" ]; then
                if [ "$key" != "-n" ]; then
                    key="$(echo "$key"|sed -e "s/---/--/g"|xargs -d ' '| tr -d '\n')"
                fi
                if [ "$key" != "-" ]; then
                    local value=$(echo "$value"|xargs -d ' '| tr -d '\n')
                    old_value=${parse_arguments_args["$key"]}
                    if [ "$old_value" != "$value" ]; then
                        if [ "$old_value" ] && [ "$value" != "true" ]; then
                            if [ "$value" ]; then
                                value="$old_value,$value"
                            else
                                value="$old_value"
                            fi
                        fi
                        # if [ "$old_value" ]; then
                        #     print_gray "old_value: [$old_value], value: [$value]"
                        # fi

                        parse_arguments_args["$key"]="$value"
                    fi
                fi
            fi
        done
    fi

    get_arg verbose '--verbose'
    if [ "$verbose" ]; then
        debug="true"
        for key in "${!parse_arguments_args[@]}"; 
        do 
            key="${key}"
            value="${parse_arguments_args[${key}]}"
        done
    fi
    IFS=$old_SEP
}

get_arg()
{
    local -n value="$1"
    local old_SEP=$IFS
    local global="true"
    if [ "$4" ];then
        local -n get_arg_args="$4"
    fi

    if [ "$5" ];then
        local global="$5"
    fi

    if [ "$global" != "true" ]; then
        value=""
    fi
    
    # echo "keys: $2"
    IFS=","; read -ra keys <<< "$2";
    for key in "${keys[@]}"
    do
        if [ ! "$key" = "-n" ]; then
            key="$(echo "$key"|xargs -d ' '| tr -d '\n')" 
        fi
        key_value=""
        if [ ! "$4" ];then
            key_value="${ARGS[$key]}"
        else
            key_value="${get_arg_args[$key]}"
        fi
        if [ "$key_value" ]; then
            if [ "$value" ] && [ "$value" != "true" ];then
                value="$value,$key_value"
            else
                value="$key_value"
            fi
        fi
    done

    if [ ! "$value" ] && [ "$3" ]; then
        value="$3"
    fi
    IFS=$old_SEP
    if [ "$value" ] && [ "$1" != "debug" ] && [ "$1" != "verbose" ];  then
        if [ "$global" == "true" ]; then
            print_verbose "Loaded argument $1:'$value'"
        fi
    fi
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
    if [ ! "$skip_newline" ]; then
        echo ""
    fi

    printf "$color$question $normal"
    read  answer
    lower answer
    if [ "$1" = "yes_no" ]; then
        if [ "$answer" = "yes" ] || [ "$answer" = "y" ] || [ "$answer" = "ja" ] || [ "$answer" = "j" ]; then
            answer="yes"
        elif [ "$answer" = "no" ] || [ "$answer" = "n" ] || [ "$answer" = "nei" ]; then
            answer="no"
        fi
    fi
    print_debug "You selected: $answer"
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
    parse_arguments run_command_args "$@"
    get_arg command_from_var '--command-var,--command-from-var,--command-in-var' '' run_command_args false
    get_arg debug_title '--debug-title,-dt' '' run_command_args false
    get_arg return_in_var '--return-in-var,--return-var,--return' '' run_command_args false
    get_arg force_debug_title '--force-debug-title,-dt' '' run_command_args false
    get_arg error_code '--error-code' '' run_command_args false
    get_arg skip_error '--skip-error' '' run_command_args false
    get_arg skip_shell '--skip-shell' '' run_command_args false
    get_arg return_array '--return-array,--array' '' run_command_args false

    if [ "$command_from_var" ];then
        local -n command="$command_from_var"
    else
        get_arg command '--command,--command,-c' '' run_command_args false
    fi


    if [ "$return_in_var" ];then
        local -n run_command_result="$return_in_var"
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
                dummy="$(git config --add default.branch $default_branch)"
            fi
        fi
        # print_debug "git__setup(): [ default_branch='$default_branch' ]"
    else
        old="$(git config --get default.branch)"
        if [ "$old" ]; then
            dummy="$(git config --unset default.branch)"
       fi
       dummy="$(git config --add default.branch $default_branch)"
    fi
    current_branch="$(git branch --show-current)"
    if [ ! "$current_branch" ]; then
        current_branch="$default_branch"
    fi

    if [ ! "$upstream_url" ]; then
        upstream_url="$(git config --get remote.upstream.url)"
    fi

    # print_debug "git__setup(): [ default_branch='$default_branch',  current_branch='$current_branch', upstream_url='$upstream_url' ]"


    if [ ! "$from_commit" ] && [ ! "$from_date" ] && [ "$current_branch" ] ; then
        from_commit_command="git rev-list $current_branch -1 2>/dev/null"
        {
            run_command from-commit --command-var from_commit_command --return-var from_commit --skip-error --debug-title "from-commit-command"
        } || {
            if [ "$from_init_repo_function" != "true" ]; then
                printf "${red}No commits found, run ${gray}smud init ${red} to fetch the upstream repository. -- $from_init_repo_function\n${normal}"
                exit
            fi
        }
    fi

    if [ ! "$to_commit" ] && [ ! "$is_smud_dev_repo" ];then
        if [ ! "$source_branch" ]; then
            source_branch="$(git config --get source.$current_branch)"
        fi
        if [ ! "$source_branch" ]; then
            source_branch="upstream/$default_branch"
        fi
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

first_param="$3"
shift
parse_arguments ARGS $@

curr_dir="$(pwd)"
namespace_filter="-A"

get_arg silent '--silent'
get_arg verbose '--verbose'
get_arg debug '--debug' "$verbose"
print_verbose "**** START: include.sh"
print_debug "Loading arguments...\n"
get_arg upstream_url '--upstream-url,--upstream,--up-url,-up-url'
get_arg source_branch '--source-branch,--source'
get_arg default_branch '--default-branch'
get_arg configs '--configs,--config,--settings,--setting,--show'
get_arg skip_auto_update '--skip-auto-update,--skip-auto'
get_arg examples '--examples,--ex,-ex'
get_arg help '--help,-?,-h' "$examples"
get_arg separator '--separator,-sep'
get_arg col_separator '--col-separtor,-colsep', ' '
get_arg new '--new'
get_arg major '--major'
get_arg minor '--minor'
get_arg patch '--patch'
get_arg same '--same'
get_arg changed '--changed,--changes,--release,--released'
get_arg installed '--installed,-I'
get_arg hide_title '--hide-title'

get_arg product '--products,--product,-P,--P'
get_arg all '--all,-A'
get_arg version '--version,-V'
get_arg from_commit '--from-commit,-FC'
get_arg to_commit '--to-commit,-TC'
get_arg from_date '--from-date,-FD'
get_arg to_date '--to-date,-TD'
get_arg grep '--grep'
get_arg undo '--undo,--reset'
get_arg soft '--soft'
get_arg undo_date '--date'
get_arg no_progress '--no-progress,--skip-progress' "$silent"
get_arg skip_push '--skip-push,--no-push'
get_arg skip_files '--skip-files,--no-files'
get_arg show_files '--show-files,--files'
get_arg responsible '--responsible,--team'
get_arg conflicts_files '--conflict-files,--files'
get_arg merge_ours '--merge-ours,--our,--ours'
get_arg merge_theirs '--merge-theirs,--their,--theirs'
get_arg merge_union '--merge-union,--union'
get_arg namespace '--namespace,-N,-n'
get_arg development '--development,-D,-DEV,--DEV'
get_arg external_test '--external-test,-ET,--ET'
get_arg internal_test '--internal-test,-IT,--IT'
get_arg production '--production,-PROD,--PROD'
get_arg stage '--stage,-S' '**'

grep="$(echo "$grep"| sed -e 's/true//g')"

if [ "$namespace" ]; then
    namespace_filter="-n $namespace"
fi

if [ "$to_commit" = "true" ]; then
    to_commit=""
fi
if [ "$from_commit" = "true" ]; then
    from_commit=""
fi

if [ "$conflicts_files" ]; then
    conflicts_files=$(echo "$conflicts_files"| awk  --field-separator=, '{ print $1}'|uniq)
fi

if [ "$responsible" ]; then
    responsible=$(echo "$responsible" | sed -e "s/\./\\./g" -e 's/*/.*/g') 
fi

if [ "$skip_files" ]; then
    show_files="" 
fi

remote_origin=""
if [ -d ".git" ]; then
    is_repo="true"
    is_smud_cli_repo=""
    is_smud_gitops_repo=""
    
    cGitOps=$(expr match "$(pwd)" '.*/SMUD-GitOps$')
    cSmudCli=$(expr match "$(pwd)" '.*/smud-cli$')
    if [ $cGitOps -gt 0 ]; then
        if [ "$(git config --get remote.origin.url|grep 'dev.azure.com/dips/DIPS/_git')" ]; then
            is_smud_gitops_repo="SMUD-GitOps"
        fi
    elif [ $cSmudCli -gt 0 ]; then
        is_smud_cli_repo="smud-cli"
    fi
    # echo "is_smud_gitops_repo: '$is_smud_gitops_repo'"
    # echo "is_smud_cli_repo: '$is_smud_cli_repo'"
fi

skip_init_feature=""
if [ "$is_smud_gitops_repo"  ]; then
    installed="true"
fi

if [ "$is_smud_gitops_repo"  ] || [ "$is_smud_cli_repo" ] || [ "$(pwd)" == "$HOME" ]; then
    skip_init_feature="true"
fi

is_smud_dev_repo="$is_smud_gitops_repo$is_smud_cli_repo"

if [ "$is_smud_gitops_repo" ] && [ "$changed" ]; then
    stage=""
    development=""
    internal_test='true'
    external_test='true'
    production='true'
    show_changes_only='true'
    show_files=""
    skip_dependecies="true"
fi

if [ "$development" ]; then   
    if [ "$stage" = "**" ]; then stage="";fi
    stage="$stage development"
fi
if [ "$internal_test" ]; then   
    if [ "$stage" = "**" ]; then stage="";fi
    stage="$stage internal-test"
fi

if [ "$external_test" ]; then
    if [ "$stage" = "**" ]; then stage="";fi
    stage="$stage external-test"
fi

if [ "$production" ]; then   
    if [ "$stage" = "**" ]; then stage="";fi
    stage="$stage production"
fi

stage="$(echo "$stage"|xargs|sed -e 's/ /,/g'|xargs)"
selected_stage="$stage"
if [ "$selected_stage" = "**" ]; then
    selected_stage=""
fi
if [ "$product" = "true" ]; then
    product=""
    all="true"
fi

selected_product="$product"
if [ "$selected_product" = "**" ]; then
    selected_product=""
fi

filter_product_name="[$product] "
if [ "$filter_product_name" = "[**] " ] || [ ! "$is_smud_gitops_repo" ]; then
    filter_product_name=""
fi

can_list_direct=""
if ([ ! "$is_smud_gitops_repo" ] || [ "$filter_product_name" ]) && [ ! "$new" ]; then
    can_list_direct="1"
fi

print_verbose "can_list_direct=$can_list_direct, is_smud_gitops_repo=$is_smud_gitops_repo, filter_product_name=$filter_product_name, new=$new"

if [ "$grep" ]; then
    git_grep="$(echo "$grep"| sed -e 's/ /./g'| sed -e 's/"//g'| sed -e "s/'//g" )"
    git_grep="--grep $git_grep"
fi

git_pretty_commit='--pretty=format:%H'
git_pretty_commit_date='--pretty=format:%H|%ad'
current_branch="$default_branch"
if [ "$has_args" ] && [ ! "$help" ] && [ "$is_repo" ]; then
    git__setup 
fi

if [ "$all" ] && [ ! "$product" ]; then
    product="**"
fi

if [ "$installed" ] && [ ! "$product" ]; then
    product="**"
fi

setup__product_filters

devops_model_filter="GETTING_STARTED.md CHANGELOG.md applicationsets-staged/* environments/* gitops-engine/* repositories/*"
diff_filter=''

if [ "$debug" ];then
    print_debug "filter: $filter"
    if [ "$installed" ]; then
        print_debug "app_files_filter: $app_files_filter"
    fi
    if [ "$can_do_git" ]; then
        print_debug "Can do commit:"
        if [ "$commit_range" ]; then
            if [ "$from_commit" ]; then print_debug "  from-commit: $from_commit"; fi
            if [ "$to_commit" ]; then print_debug "  to-commit: $to_commit"; fi
            print_debug "  commit range: $commit_range"
        fi
        if [ "$date_range" ]; then
            if [ "$from_date" ]; then print_debug "  from-date: $from_date"; fi
            if [ "$to_date" ]; then print_debug "  from-date: $to_date"; fi
            print_debug "date range: $date_range"
        fi
    fi
fi
git_range="$(echo "$commit_range $date_range"|xargs)"
if [ "$git_range" ] && [ "$git_grep" ]; then
    git_range="$git_range $git_grep"
fi

if [ ! "$all" ]; then
    if [ ! "$new$major$minor$patch$same$changed$product$version$responsible$stage" ]; then
        all="true"
    fi
fi


# has_any_commits="$(git log ..5e21036a024abd6eb8d1aaa9ffe9f6c14687821c --max-count=1 --no-merges $git_pretty_commit -- $filter)"
# echo "hit: $has_any_commits"
# exit
print_verbose "**** END: include.sh"
