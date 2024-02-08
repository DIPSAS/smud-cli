#!/usr/bin/env bash

default_upstream="https://github.com/DIPSAS/DIPS-GitOps-Template.git"

# Rewrite this to not use arg array
set_upstream()
{
    new_upstream="$1"
    if [ ! "$new_upstream" ]; then
        new_upstream="$upstream_url"
    fi
    if [ ! "$new_upstream" ]; then
        new_upstream="$first_param"
    fi

    if [ "$help" ]; then
        echo "${bold}smud set-upstream${normal}: Set upstream"
        printf "With Only ${green}set-upstream${normal}, Upstream '$default_upstream' will be configured if not configured yet. \n"
        printf "With ${green}set-upstream ${bold}<value>${normal}, Upstream '<value>' will be configured. \n"
        printf "With ${green}set-upstream ${bold}--upstream-url <value>${normal}, Upstream '<value>' will be configured. \n"
        printf "With ${green}set-upstream ${bold}-${normal}, Upstream will be removed. \n"
        return
    fi

    if [ ! "$is_repo" ]; then
        print_not_silent "${red}'$(pwd)' is not a git repository! ${normal}\n"
        return
    fi

    i=0
    
    if [ "$new_upstream" ]; then
        remove_upstream_command="git remote rm upstream"
        run_command remove-upstream --command-from-var=remove_upstream_command --debug-title='Removing upstream config URL'
        if [ "$new_upstream" = "-" ]; then
            print_not_silent "${gray}Upstream is removed${normal}\n"
            exit
        else
            add_upstream_command="git remote add upstream $new_upstream"
            run_command add_upstream_command --command-from-var=add_upstream_command --debug-title='Adding upstream with user specified URL'
            print_not_silent "${gray}Upstream configured with '$new_upstream' ${normal}\n"
        fi
    elif [ ! "$new_upstream" ]; then
        new_upstream=$default_upstream
        add_upstream_command="git remote add upstream $new_upstream"
        run_command add_upstream_command --command-from-var=add_upstream_command --debug-title='Adding upstream with default URL'
        print_not_silent "${gray}Upstream configured with '$new_upstream' ${normal}\n"
    elif [ ! "$caller" ]; then
        print_not_silent "${gray}Upstream alredy configured with '$new_upstream' ${normal}\n"
    fi
}

set_origin()
{
    if [ ! "$is_repo" ]; then
        print_not_silent "${red}'$(pwd)' is not a git repository! ${normal}\n"
        return
    fi
    
    # Check if origin exists
    check_origin_command="git config --get remote.origin.url"
    run_command check-origin --command-from-var=check_origin_command --return-in-var=remote_origin --return-var=dummy --debug-title='Checking if remote.origin.url exist in git config' || return

    # If string is empty, set the remote origin url
    if [ ! "$remote_origin" ]; then
        printf "${yellow}Remote repository origin is not set, please enter URL for the remote origin.\nOrigin URL: ${normal}"
        read user_set_remote_origin
        add_origin_command="git remote add origin $user_set_remote_origin"
        run_command set-origin --command-from-var=add_origin_command --return-var=dummy --debug-title='Adding remote origin' || return
    fi
}

merge_upstream()
{
    if [ "$skip_auto_update" ]; then
        return
    fi
    print_not_silent "${gray}Merging upstream into local branch...$reset"
    merge_upstream_command="git merge upstream/main"
    run_command merge-upstream --command-from-var=merge_upstream_command --return-var=dummy --debug-title='Merging upstream repository into local branch' || return
}

fetch_origin()
{
    if [ "$skip_auto_update" ]; then
        return
    fi
    print_not_silent "${gray}Fetching origin...$reset"
    fetch_origin_command="git fetch origin"
    run_command fetch-origin --command-from-var=fetch_origin_command --return-var=dummy --debug-title='Fetching origin' || return
} 

init_repo()
{
    init_command="git init"
    run_command init-repo --command-from-var=init_command --return-var=dummy --debug-title='Initializing repository' || return
    is_repo="true"

    branches=$(git branch)
    if [ ! -n "$branches" ]; then
        # "main" possibly not default branch name so create it
        create_main_branch="git checkout -b main"
        run_command checkout-main --command-from-var=create_main_branch --return-var=dummy --debug-title='Creating main branch' || return
    fi 
}

fetch_upstream()
{
    fetch_upstream_command="git fetch upstream"
    run_command fetch-upstream --command-from-var=fetch_upstream_command --return-var=dummy --debug-title='Fetching upstream' || return
} 

# Initalizes repo, upstream and origin if not configured. Will always fetch upstream when called.
init()
{
    if [ "$help" ]; then
        func=${1:-init}
        echo "${bold}smud $func${normal}: Initializes local repository and sets upstream and origin remotes"
        printf "With Only ${green}$func${normal}, Upstream '$default_upstream' will be configured if not configured yet. When configured the upstream will be fetched. \n"
        printf "With ${green}$func ${bold}<value>${normal}, Upstream '<value>' will be configured before upstream is fetched. \n"
        printf "With ${green}$func ${bold}--upstream-url <value>${normal}, Upstream '<value>' will be configured before upstream is fetched. \n"
        printf "With ${green}$func ${bold}-${normal}, Upstream will be removed. \n"
        return
    fi
    if [ ! "$upstream_url" ]; then
        upstream_url="$1"
        if [ ! "$upstream_url" ]; then
            upstream_url="$first_param"
        fi
    fi
    remote_origin=$(git config --get remote.origin.url)
    remote_upstream=$(git config --get remote.upstream.url)

    if [ ! "$remote_upstream" ] || [ "$upstream_url" ]; then
        if [ ! "$upstream_url" ]; then
            upstream_url="$default_upstream"
        fi
        set_upstream "$upstream_url"
    fi

    print_debug "upstream_url: $upstream_url"

    if [ ! "$is_repo" ]; then
        local yes_no="yes"
        if [ ! "$silent" ]; then
            ask yes_no $yellow "The current directory does not seem to be a git repository\nWould you like to initialize the repository and merge the remote upstream? (yes/no)"
        fi
        if [ ! "$yes_no" = "yes" ]; then
            print_not_silent "${yellow}Aborting"
            exit 0
        fi
        init_repo
        fetch_upstream
        merge_upstream
    else
        fetch_upstream
    fi

    if [ ! "$remote_origin" ]; then
        print_not_silent "Setting and fetching origin"
        set_origin
        fetch_origin
        print_not_silent "${green}Initalization complete.\n${normal}"
    fi
}