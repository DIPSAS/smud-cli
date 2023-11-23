#!/usr/bin/env bash
declare -A ARGS

get_arg()
{
    keys=$(echo $1 | tr ',' '\n')
    arg=""
    for key in $keys
    do
        if [ ! $arg ];then
          arg=${ARGS[$key]}
        fi  
    done

    if [ ! $arg ]; then
        arg="$2"
    fi

    echo "$arg"
}

white='\033[1;37m' 
magenta='\x1b[1;m'
red='\x1b[22;31m'
gray='\x1b[1;90m'
yellow='\x1b[22;33m'
magenta='\033[38;5;53m'
bold=$(tput bold)
# bold=$white
normal=$(tput sgr0)
if [ $# -gt 0 ];then

  shift

  while [ $# -gt 0 ]; do
    s=$1
    IFS='=' read -r -a arg <<< "$s"
    value=${arg[1]};value="${value:-true}"
    ARGS[${arg[0]}]=$value
    shift
  done
fi

help=$(get_arg '--help,-h')
separator=$(get_arg '--separator,-sep')
col_separator=$(get_arg '--col-separator,-colsep', ' ')
new=$(get_arg '--new')
installed=$(get_arg '--installed,-I')
hide_title=$(get_arg '--hide-title')
silent=$(get_arg '--silent')
verbose=$(get_arg '--verbose,-h')
debug=$(get_arg '--debug,-h' "$verbose")
product=$(get_arg '--product,-P' '**')
development=$(get_arg '--development,-D')
external_test=$(get_arg '--external-test,-ET')
internal_test=$(get_arg '--internal-test,-IT')
production=$(get_arg '--production,-PROD')
stage=$(get_arg '--stage,-S' '*')
if [ $external_test ]; then
    stage="external-test"
elif [ $production ]; then   
    stage="production"
elif [ $internal_test ]; then   
    stage="internal-test"
elif [ $development ]; then   
    stage="development"
fi

selected_stage=$stage
if [ "$selected_stage" = "*" ]; then
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

if [ $verbose ];then
    echo "can_list_direct=$can_list_direct, is_smud_gitops_repo=$is_smud_gitops_repo, filter_product_name=$filter_product_name, new=$new"
fi

from_commit=$(get_arg '--from-commit,-FC')
to_commit=$(get_arg '--to-commit,-TC')
if [ ! $help ] && [ ! $installed ] && [ "$is_repo" ]; then
    if [ ! $from_commit ];then
        from_commit=$(git log main -1  --pretty=format:"%H")
    fi

    if [ ! $to_commit ] && [ ! $is_smud_dev_repo ];then
        to_commit=$(git log upstream/main -1  --pretty=format:"%H")
    fi

    commit_range=$from_commit..$to_commit
fi

app_filter="products/$product/$stage/app.yaml"

filter=":products/$product/$stage/** products/$product/product.yaml"
diff_filter=''

if [ $debug ];then
    echo "filter: $filter"
    echo "from-commit: $from_commit"
    echo "to-commit: $to_commit"
    echo "commit range: $commit_range"
fi


