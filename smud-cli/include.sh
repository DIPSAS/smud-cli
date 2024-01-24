#!/usr/bin/env bash

white='\033[1;37m' 
magenta='\x1b[1;m'
green='\x1b[22;32m'
red='\x1b[22;31m'
gray='\x1b[1;90m'
yellow='\x1b[22;33m'
magenta='\033[38;5;53m'
bold=$(tput bold)
# bold=$white
normal=$(tput sgr0)

declare -A ARGS

parse_arguments()
{
    local -n parse_arguments_args=$1

    shift
    if [ $# -gt 0 ];then
        has_args="true"
        local str=$(echo " $@"|sed -e 's/--/-_sep_/g' |sed -e 's/ -/§/g')
        # echo "str: $str"
        IFS="§"; read -ra array <<< " $str";
        local c=$(echo "${array[0]}" | grep '-' -c)
        if [ $c -eq 0 ]; then
            shift
            if [ $# -eq 0 ];then
                return
            fi
            local str=$(echo " $@"|sed -e 's/--/-_sep_/g' |sed -e 's/ -/§/g')
            # echo "str: $str"
            IFS="§"; read -ra array <<< " $str";
        fi
                
        for s in "${array[@]}"
        do
            if [ ! "$s" ] || [ "$s" = " " ]; then
                continue
            fi
            local s=$(echo "$s"|xargs -d ' '| tr -d '\n')
            # echo "s: $s"
            local s=$(echo "-$s" |sed -e 's/_sep_/-/g')
            # echo "s: $s"
            IFS='='; read -ra arg <<< "$s"
            local key=$(echo "${arg[0]}"|xargs -d ' '| tr -d '\n')
            local value="${arg[1]}"
            if [ ! "$value" ]; then
                local c=$(echo "$s" | grep ' ' -c)
                if [ $c -gt 0 ]; then
                    IFS=' ';read -ra arg <<< "$s"
                    local key=$(echo "${arg[0]}")
                    local value=$(echo "$s"|sed -e "s/$key //g"|xargs -d ' '| tr -d '\n')
                fi
            fi
            local value="${value:-true}"

            if [ "$key" ]; then
                key="$(echo "$key"|sed -e "s/---/--/g"|xargs -d ' '| tr -d '\n')"
                local value=$(echo "$value"|xargs -d ' '| tr -d '\n')
                parse_arguments_args["$key"]="$value"
            fi
        done
    fi

    get_arg verbose '--verbose'
    if [ "$verbose" ]; then
        debug="true"
        print_verbose "List all input arguments"
        for key in "${!parse_arguments_args[@]}"; 
        do 
            key="${key}"
            value="${parse_arguments_args[${key}]}"
            print_verbose "{ key: '$key', value='$value' }"; 
        done
    fi
}

get_arg()
{
    local -n value=$1
    if [ "$4" ];then
        local -n get_arg_args=$4
    fi
    # echo "keys: $2"
    IFS=","; read -ra keys <<< "$2";
    value=""
    for key in "${keys[@]}"
    do
        key=$(echo "$key"|xargs -d ' '| tr -d '\n') || print_error $key
        # print_verbose "get_args: key='$key'"
        if [ ! "$value" ];then
            if [ ! "$4" ];then
                value="${ARGS[$key]}"
                # print_verbose "*** get_args(0): { key='$key', value='$value' }"                
            else
                value="${get_arg_args[$key]}"
                # print_verbose "*** get_args(1): { key='$key', value='$value' }"                
            fi
        fi
        if [ "$value" ]; then
            return
        fi    
    done

    if [ ! "$value" ] && [ "$3" ]; then
        value="$3"
    fi
}

fix_print_message()
{
    msg="$(echo "$1"| sed -e 's/%/%%/g')"
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
        print_gray "$1"
    fi
}

print_verbose() 
{
    if [ "$verbose" ]; then
        print_gray "$1"
    fi
}

lower()
{
    local -n str=$1
    str=$(echo "$str" | tr '[:upper:]' '[:lower:]')
}

ask()
{
    local -n answer=$1
    local color=$2
    local question=$3

    echo ""
    print_color $color $question
    read  answer
    lower answer
    print_gray "You selected: $answer"

}


progressbar__init()
{
    progressbar__start_time=$(date +"%Y-%m-%d %H:%M:%S")
    progressbar__last_drawn=0
    progressbar__enable_default_flag="true"
    progressbar__size=$1
    progressbar__enable_size=$2
    progressbar__line_info_enabled=${3:-true}
    if [ "$no_progress" ]; then
        progressbar__enable_default_flag=""
    fi
    progressbar__enabled=""
    if [ $progressbar__size -gt $progressbar__enable_size ]; then
        progressbar__enabled=$progressbar__enable_default_flag
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
            echo "$progressbar__message$progressbar__linmessage"
        else 
            local bar_percentage_value=$((100 * $progressbar__current/$progressbar__size))
            local bar_percentage_chars=$(($bar_percentage_value/2))
            local bar_chars="$(printf %${bar_percentage_chars}s "" | tr ' ' '#')"
            local bar_print="`printf %-50s $bar_chars`"
            local bar_percentage_print="(`printf %-3s $bar_percentage_value`%)"
            echo -ne "$bar_print  $bar_percentage_print -- $progressbar__message$progressbar__linmessage                    \\r"
        fi    
        progressbar__last_drawn=$progressbar__current
    fi
}

progressbar__end()
{
    if [ "$progressbar__enabled" ]; then
        local msg=$progressbar__message
        if [ "$1" ]; then
            msg=$1
        fi
        progressbar__last_drawn=-5
        progressbar__increase $progressbar__size "$msg"
        echo -ne '\n'
        progressbar__enabled=""
    fi

    if [ "$2" ]; then
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
    get_arg command_from_var '--command-var,--command-from-var,--command-in-var' '' run_command_args
    get_arg debug_title '--debug-title,-dt' '' run_command_args
    get_arg return_in_var '--return-var,--return-in-var' '' run_command_args
    get_arg error_code '--error-code' '' run_command_args
    get_arg skip_error '--skip-error' '' run_command_args

    if [ "$command_from_var" ];then
        local -n command=$command_from_var
    else
        get_arg command '--command,--command,-c' '' run_command_args
    fi


    if [ "$return_in_var" ];then
        local -n run_command_result=$return_in_var
    fi
    if [ "$error_code" ];then
        local -n run_command_error_code=$error_code
    fi

    run_command_error_code=0
    run_command_result=""


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
    if [ "$debug" ] && [ "$return_in_var" ]; then
        if [ ! "$debug_title" ]; then
            local debug_title="Running command"
        fi
        print_debug "$debug_title:\n$command"
    fi
    {
        run_command_result="$(sh -c "$command" 2>&1)"
        run_command_error_code=$?
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

    if [ ! "$return_in_var" ];then
        echo "$run_command_result"
    fi

}

parse_arguments ARGS $@
curr_dir=$(pwd)
get_arg examples '--examples,--ex,-ex'
get_arg help '--help,-?,-h' "$examples"
get_arg separator '--separator,-sep'
get_arg col_separator '--col-separtor,-colsep', ' '
get_arg new '--new'
get_arg major '--major'
get_arg minor '--minor'
get_arg patch '--patch'
get_arg same '--same'
get_arg installed '--installed,-I'
get_arg hide_title '--hide-title'
get_arg silent '--silent'
get_arg verbose '--verbose'
get_arg debug '--debug' "$verbose"
get_arg product '--products,--product,-P,--P'
get_arg all '--all,-A'
get_arg version '--version,-V'
get_arg from_commit '--from-commit,-FC'
get_arg to_commit '--to-commit,-TC'
get_arg from_date '--from-date,-FD'
get_arg to_date '--to-date,-TD'
get_arg grep '--grep'
get_arg no_progress '--no-progress' "$silent"
get_arg skip_files '--skip-files'
get_arg files '--files'

get_arg development '--development,-D,-DEV'
get_arg external_test '--external-test,-ET'
get_arg internal_test '--internal-test,-IT'
get_arg production '--production,-PROD'
grep=$(echo "$grep"| sed -e 's/true//g')
get_arg stage '--stage,-S' '**'

if [ $development ]; then   
    if [ "$stage" = "**" ]; then stage="";fi
    stage="$stage development"
fi
if [ $internal_test ]; then   
    if [ "$stage" = "**" ]; then stage="";fi
    stage="$stage internal-test"
fi

if [ "$external_test" ]; then
    if [ "$stage" = "**" ]; then stage="";fi
    stage="$stage external-test"
fi

if [ $production ]; then   
    if [ "$stage" = "**" ]; then stage="";fi
    stage="$stage production"
fi
stage="$(echo "$stage"|xargs|sed -e 's/ /,/g'|xargs)"
selected_stage=$stage
if [ "$selected_stage" = "**" ]; then
    selected_stage=""
fi

selected_product=$product
if [ "$selected_product" = "**" ]; then
    selected_product=""
fi

if [ -d ".git" ]; then
    is_repo="true"
    is_smud_gitops_repo=$(echo "$(pwd)"| grep "/SMUD-GitOps")
    is_smud_cli_repo=$(echo "$(pwd)"| grep "/smud-cli")
fi

is_smud_dev_repo="$is_smud_gitops_repo$is_smud_cli_repo"

filter_product_name="[$product] "
if [ "$filter_product_name" = "[**] " ] || [ ! "$is_smud_gitops_repo" ]; then
    filter_product_name=""
fi

can_list_direct=""
if ([ ! "$is_smud_gitops_repo" ] || [ $filter_product_name ]) && [ ! "$new" ]; then
    can_list_direct="1"
fi

print_verbose "can_list_direct=$can_list_direct, is_smud_gitops_repo=$is_smud_gitops_repo, filter_product_name=$filter_product_name, new=$new"

if [ "$grep" ]; then
    git_grep=$(echo "$grep"| sed -e 's/ /./g'| sed -e 's/"//g'| sed -e "s/'//g" )
    git_grep="--grep $git_grep"
fi
git_pretty_commit='--pretty=format:%H'
git_pretty_commit_date='--pretty=format:%H|%ad'
default_branch="main"
upstream_url=""
if [ $has_args ] && [ ! $help ] && [ "$is_repo" ]; then
    default_branch="$(git config --list | grep -E 'branch.(main|master).remote' | sed -e 's/branch\.//g' -e 's/\.remote//g' -e 's/=origin//g')"
    upstream_url="$(git config --get remote.upstream.url)"
    if [ ! "$default_branch" ]; then
        default_branch=$(git config --get init.defaultbranch)
    fi

    if [ ! "$default_branch" ]; then
        default_branch="main"
        can_do_git=""
    else
        can_do_git="$(git branch --list $default_branch)"
    fi

    if [ ! "$from_commit" ] && [ ! "$from_date" ] && [ "$can_do_git" ] ; then
        {
            $(git log > /dev/null 2>&1)
            from_commit=$(git log $default_branch -1 --pretty=format:"%H")
        } || {
            printf "${red}No commits found, run ${gray}smud init ${red} to fetch the upstream repository.\n${normal}"
            exit
        }
    fi

    if [ ! $to_commit ] && [ ! $is_smud_dev_repo ];then
        if [ "$upstream_url" ]; then
            to_commit=$(git log upstream/$default_branch -1 --pretty=format:"%H" > /dev/null 2>&1)
            if [ $? -eq 0 ];then
                to_commit=$(git log upstream/$default_branch -1 --pretty=format:"%H")
            fi
        fi
    fi
    
    if [ "$from_commit$to_commit" ]; then
        commit_range=$from_commit..$to_commit
    fi
    if [ "$from_date" ]; then
        date_range="--since $(echo "$from_date"| sed -e 's/ /./g')" 
    fi
    if [ "$to_date" ]; then
        date_range="$date_range --before $(echo "$to_date"| sed -e 's/ /./g')" 
    fi
    if [ "$version" ]; then
        git_grep_version=-GchartVersion:.$version
        git_grep="$git_grep $git_grep_version"
    fi
fi

if [ "$all" ] && [ ! "$product" ]; then
    product="**"
fi

if [ "$installed" ] && [ ! "$product" ]; then
    product="**"
fi


c=$(echo "$product" | grep ',' -c)
c1=$(echo "$stage" | grep ',' -c)
if [ ! $c -eq  0 ] || [ ! $c1 -eq  0 ]; then
    stage=$(echo "$stage"| sed -e 's/ /,/g'|sed -e 's/ //g'| sed -e 's/,,/,/g')        
    IFS=',';read -ra selected_stages <<< "$stage"
    product=$(echo "$product"| sed -e 's/ //g'| sed -e 's/,,/,/g')    
    IFS=',';read -ra selected_products <<< "$product"
    app_files_filter=""
    no_app_files_filter=""
    filter=""
    ls_filter=""
    for stage in "${selected_stages[@]}"
    do
        for p in "${selected_products[@]}"
        do
            print_verbose "p: '$p'"
            if [ "$app_files_filter" ];then
                app_files_filter="$app_files_filter products/$p/$stage/app.yaml"
                no_app_files_filter="$app_files_filter ^products/$p/$stage/app.yaml"
            else
                app_files_filter="products/$p/$stage/app.yaml"
                no_app_files_filter="^products/$p/$stage/app.yaml"
            fi;

            if [ ! "$filter" ];then
                filter="products/$p/$stage/** products/$p/product.yaml"
            else
                filter="$filter products/$p/$stage/** products/$p/product.yaml"
            fi
        done
    done
else    
    app_files_filter="products/$product/$stage/app.yaml"
    no_app_files_filter="^products/$product/$stage/app.yaml"
    filter="products/$product/$stage/** products/$product/product.yaml"
fi
filter_=$filter
filter=":$filter"
devops_model_filter="GETTING_STARTED.md CHANGELOG.md applicationsets-staged/* environments/* gitops-engine/* repositories/*"
diff_filter=''

if [ $debug ];then
    print_debug "filter: $filter"
    if [ "$installed" ]; then
        print_debug "app_files_filter: $app_files_filter"
    fi
    if [ "$can_do_git" ]; then
        print_debug "Can do commit:"
        if [ "$commit_range" ]; then
            if [ $from_commit ]; then print_debug "  from-commit: $from_commit"; fi
            if [ $to_commit ]; then print_debug "  to-commit: $to_commit"; fi
            print_debug "  commit range: $commit_range"
        fi
        if [ "$date_range" ]; then
            if [ $from_date ]; then print_debug "  from-date: $from_date"; fi
            if [ $to_date ]; then print_debug "  from-date: $to_date"; fi
            print_debug "date range: $date_range"
        fi
    fi
fi
git_range="$(echo "$commit_range $date_range"|xargs)"
if [ "$git_range" ] && [ "$git_grep" ]; then
    git_range="$git_range $git_grep"
fi
# has_any_commits=$(git log ..5e21036a024abd6eb8d1aaa9ffe9f6c14687821c --max-count=1 --no-merges $git_pretty_commit -- $filter)
# echo "hit: $has_any_commits"
# exit

