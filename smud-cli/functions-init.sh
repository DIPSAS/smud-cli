#!/usr/bin/env bash

set_upstream()
{
    caller=$1
    if [ $help ]; then
        echo "${bold}smud set-upstream${normal}: Set upstream"
        printf "With Only ${green}set-upstream${normal}, Upstream '$default_upstream' will be configured if not configured yet. \n"
        printf "With ${green}set-upstream ${bold}<value>${normal}, Upstream '<value>' will be configured. \n"
        printf "With ${green}set-upstream ${bold}-${normal}, Upstream will be removed. \n"
        return
    fi

    if [ ! "$is_repo" ]; then
        printf "${red}'$(pwd)' is not a git repository! ${normal}\n"
        return
    fi

    i=0
    new_value="${arg[0]}"
    echo "upstream url: $new_value"
    while [[ "$new_value" == "--"* ]]; do
        i=$((i+1))
        new_value="${arg[$i]}"
    done
    
    remote_upstream=$(git config --get remote.upstream.url)
    if [ $new_value ]; then
        remote_upstream=$new_value
        if [ $remote_upstream ]; then
            git remote rm upstream > /dev/null 2>&1
        fi    
        if [ "$remote_upstream" = "-" ]; then
            printf "${gray}Upstream is removed${normal}\n"
            exit
        else
            git remote add upstream $remote_upstream > /dev/null 2>&1
            printf "${gray}Upstream configured with '$remote_upstream' ${normal}\n"
        fi
    elif [ ! $remote_upstream ]; then
        remote_upstream=$default_upstream
        git remote add upstream $remote_upstream > /dev/null 2>&1
        printf "${gray}Upstream configured with '$remote_upstream' ${normal}\n"
    elif [ ! "$caller" ]; then
        printf "${gray}Upstream alredy configured with '$remote_upstream' ${normal}\n"
    fi
}

set_origin()
{
    if [ ! "$is_repo" ]; then
        printf "${red}'$(pwd)' is not a git repository! ${normal}\n"
        return
    fi
    
    # Check if origin exists
    remote_origin=$(git config --get remote.origin.url)

    # If string is empty, set the remote origin url
    if [ ! -n "$remote_origin" ]; then
        printf "${yellow}Remote repository origin is not set, please enter URL for the remote origin.\nOrigin URL: ${normal}"
        read user_set_remote_origin
        $(git remote add origin $user_set_remote_origin)
        printf "${green}Remote origin set to $user_set_remote_origin\n${normal}"
    fi
}

merge_upstream()
{
    printf "${gray}Merging upstream repository into local branch\n${normal}"
    {
        $(git merge upstream/main)
    } || {
        printf "${red}Failed to merge repository into local branch\n${normal}"
    }
    printf "${green}Repository merged\n${normal}"
}

fetch_origin()
{
    printf "${gray}Fetching origin\n${normal}"
    {
        $(git fetch origin > /dev/null 2>&1) 
    } || {
        printf "Failed to fetch origin\n"
        return
    }
    printf "${green}Origin fetched\n${normal}"
} 

init_repo()
{
    
    $(git init > /dev/null 2>&1)
    is_repo="true"

    branches=$(git branch)
    if [ ! -n "$branches" ]; then
        # "main" possibly not default branch name so create it
        $(git checkout -b main)
    fi 
}

fetch_upstream()
{
    printf "${gray}Fetching upstream\n${normal}"
    {
        $(git fetch upstream > /dev/null 2>&1) 
    } || {
        printf "Failed to fetch upstream\n"
        return
    }
    printf "${green}Upstream fetched\n${normal}"
} 

# Initalizes repo, upstream and origin if not configured. Will always fetch upstream when called.
init()
{
    if [ $help ]; then
        func=${1:-init}
        echo "${bold}smud $func${normal}: Initializes local repository and sets upstream and origin remotes"
        printf "With Only ${green}$func${normal}, Upstream '$default_upstream' will be configured if not configured yet. When configured the upstream will be fetched. \n"
        printf "With ${green}$func ${bold}<value>${normal}, Upstream '<value>' will be configured before upstream is fetched. \n"
        printf "With ${green}$func ${bold}-${normal}, Upstream will be removed. \n"
        return
    fi

    remote_origin=$(git config --get remote.origin.url)
    remote_upstream=$(git config --get remote.upstream.url)
    
    if [ ! "$is_repo" ]; then
        echo "Init repo"
        init_repo
        if [ ! -n "$remote_upstream" ]; then
            set_upstream
        fi
        fetch_upstream
        merge_upstream
    else
        fetch_upstream
    fi

    if [ ! -n "$remote_origin" ]; then
        echo "Setting and fetching origin"
        set_origin
        fetch_origin
    fi
}