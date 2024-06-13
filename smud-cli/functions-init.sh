#!/usr/bin/env bash

default_upstream="https://github.com/DIPSAS/DIPS-GitOps-Template.git"

# Rewrite this to not use arg array
set_upstream()
{
    if [ "$skip_init_feature" ];then
        return
    fi    

    new_upstream="$1"
    if [ ! "$new_upstream" ]; then
        new_upstream="$upstream_url"
    fi
    if [ ! "$new_upstream" ]; then
        new_upstream="$first_param"
    fi

    cValid=$(echo "$new_upstream" | grep -E 'http://|https://|git@' -c)
    if [ ! $cValid -eq 1 ]; then
        new_upstream=""
    fi

    if [ "$help" ]; then
        echo "${bold}smud set-upstream${normal}: Set upstream"
        printf "With Only ${green}set-upstream${normal}, Upstream '$default_upstream' will be configured if not configured yet. \n"
        printf "With ${green}set-upstream ${bold}<value>${normal}, Upstream '<value>' will be configured. \n"
        printf "With ${green}set-upstream ${bold}--upstream-url <value>${normal}, Upstream '<value>' will be configured. \n"
        printf "With ${green}set-upstream ${bold}-${normal}, Upstream will be removed. \n"
        return
    fi

    exit_if_is_not_a_git_repository "Setting upstream require a git repository!"

    i=0
    
    if [ "$new_upstream" ]; then
        run_command --command="git remote rm upstream" --force-debug-title='Removing upstream config URL'
        if [ "$new_upstream" = "-" ]; then
            println_not_silent "Upstream is removed" $gray
            exit
        else
            run_command --command="git remote add upstream $new_upstream" --force-debug-title='Adding upstream with user specified URL'
            println_not_silent "Upstream configured with '$new_upstream' " $gray
        fi
    elif [ ! "$new_upstream" ]; then
        new_upstream="$default_upstream"
        run_command --command="git remote add upstream $new_upstream" --force-debug-title='Adding upstream with default URL'
        println_not_silent "Upstream configured with '$new_upstream' " $gray
    elif [ ! "$caller" ]; then
        println_not_silent "Upstream alredy configured with '$new_upstream' " $gray
    fi
}

set_origin()
{

    if [ "$skip_init_feature" ] || [ "$installed" ];then
        return
    fi    

    exit_if_is_not_a_git_repository "Setting remote.origin.url require a git repository!"
    
    # Check if origin exists
    git_config_command="git config --get remote.origin.url"
    run_command --command-in-var=git_config_command --return-var=remote_origin --debug-title='Checking if remote.origin.url exist in git config'
    # If string is empty, set the remote origin url
    if [ ! "$remote_origin" ]; then
        ask remote_origin $yellow "Remote repository origin is not set, please enter URL for the remote origin.\nOrigin URL:" "true" 
        if [ "$remote_origin" ]; then
            println_not_silent "Setting remote origin '$remote_origin'" $gray
            run_command --command="git remote add origin $remote_origin" --force-debug-title='Setting remote origin'
        fi
    else
        println_not_silent "Remote origin '$remote_origin' already set." $gray
    fi
}

merge_upstream()
{
    if [ "$skip_init_feature" ] && [ ! "$merge" ];then
        return
    fi    

    if [ "$skip_auto_update" ] && [ ! "$merge" ]; then
        return
    fi
    
    if [ "$merge" ] && [ "$merge" != "true" ]; then
        git__setup_source_config "$merge"
    fi    
    if [ "$source_branch" ]; then
        msg="Merging upstream '$source_branch' into local branch '$current_branch' ..."
        println_not_silent "Merging upstream '$source_branch' into local branch '$current_branch' ..." $gray
        run_command --command="git merge $source_branch" --return-in-var=dev_null --debug-title="$msg"
    fi    
}

fetch_origin()
{
    if [ "$skip_init_feature" ];then
        return
    fi    

    if [ "$skip_auto_update" ]; then
        return
    fi
    if [ ! "$remote_origin" ]; then
        println_not_silent "Missing remote-origin. Fetching origin skipped..."  $gray  
        return
    fi

    println_not_silent "Fetching origin '$remote_origin' into branch '$current_branch'..." $gray  
    run_command --command="git fetch origin" --return-in-var=dev_null --debug-title='Fetching origin'
} 

git_push() 
{
    if [ ! "$remote_origin" ]; then
        println_not_silent "Missing remote-origin. Pushing skipped..."  $gray  
        return
    fi

    println_not_silent "Push current branch '$current_branch' to origin-url '$remote_origin'..." $gray  
    run_command --command="git push origin $current_branch" --return-in-var=dev_null --debug-title='Push to remote'
}

init_repo()
{
    if [ "$skip_init_feature" ];then
        return
    fi    

    if [ ! "$is_repo" ];then
        run_command --command="git init" --return-in-var=dev_null --debug-title='Initializing repository' || return
        is_repo="true"

        branches="$(git branch)"
        if [ ! -n "$branches" ]; then
            # "main" possibly not default branch name so create it
            git_checkout_command="git checkout -b main"
            run_command --command-in-var git_checkout_command --return-in-var=dev_null --debug-title='Creating main branch' || return
        fi 
    fi
    git__setup 'true'
}

fetch_upstream()
{
    if [ "$skip_init_feature" ];then
        return
    fi    

    run_command --command="git fetch upstream" --return-in-var=dev_null --force-debug-title='Fetching upstream'
} 

init_upstream_url() 
{
    if [ ! "$remote_origin" ]; then 
        remote_origin="$(git config --get remote.origin.url)" 
    fi

    if [ ! "$remote_upstream" ]; then 
        remote_upstream="$(git config --get remote.upstream.url)" 
    fi
    if [ ! "$remote_upstream" ] || [ "$upstream_url" ]; then
        if [ ! "$upstream_url" ]; then
            upstream_url="$default_upstream"
        fi
    fi
    if [ "$upstream_url" ]; then
        set_upstream "$upstream_url"
        print_debug "upstream_url: $upstream_url"
    fi
}

# Initalizes repo, upstream and origin if not configured. Will always fetch upstream when called.
init()
{
    if [ "$help" ]; then
        func="${1:-init}"
        c=$(expr match "$func" '--') 
        if [  $c -gt 0 ]; then
            func="init"
        fi
        printf "${bold}smud $func${normal}: Initializes local repository and sets ${yellow}upstream, origin remotes, source-branch${normal} and ${yellow}default-branch${normal}\n"
        printf "${yellow}upstream${normal}: \n"
        printf "  With Only ${green}$func${normal}, ${yellow}upstream${normal} '${bold}$default_upstream${normal}' will be configured if not configured yet. When configured the upstream will be fetched. \n"
        printf "  With ${green}$func ${bold}<value>${normal}, ${yellow}upstream${normal} '${bold}<value>${normal}' will be configured before upstream is fetched. \n"
        printf "  With ${green}$func ${bold}${yellow}${bold}--upstream-url <value>${normal}, ${yellow}upstream${normal} '${bold}<value>${normal}' will be configured before upstream is fetched. \n"
        printf "  With ${green}$func ${yellow}${bold}-${normal}, ${yellow}upstream${normal} will be removed. \n"
        printf "${yellow}source-branch:${normal} \n"
        printf "  With Only ${green}$func${normal}, ${yellow}source-branch${normal} will be configured to '${bold}upstream/$default_branch${normal}' . \n"
        printf "  With ${green}$func ${yellow}${bold}--source-branch <value>${normal}, ${bold}source-branch '<value>'${normal} will be configured. \n"
        printf "${yellow}default-branch:${normal} \n"
        printf "  With Only ${green}$func${normal}, ${yellow}default-branch${normal} will be configured to '${bold}main${normal}' . \n"
        printf "  With ${green}$func ${yellow}${bold}--default-branch <value>${normal}${normal}, ${bold}default-branch '<value>'${normal} will be configured. \n"
        printf "${yellow}merge upstream:${normal} \n"
        printf "  With ${green}$func ${yellow}${bold}--merge${normal} the '${bold}git merge upstream/main${normal}' command will be runned. \n"
        printf "  With ${green}$func ${yellow}${bold}--merge --push${normal} the ${gray}'git merge upstream/main; ${normal}${bold}git push${normal}' command will be runned. \n"
        printf "  With ${green}$func ${yellow}${bold}--merge <branch>${normal}${normal} the '${bold}git merge upstream/${yellow}${bold}<branch>${normal}' command will be runned. \n"
        printf "  With ${green}$func ${yellow}${bold}--merge <branch> --push${normal}${normal} the '${gray}git merge upstream/<branch>${normal}; ${bold}git push${normal}' command will be runned. \n"
        printf "Show ${yellow}configs:${normal} \n"
        printf "  ${green}$func${normal} ${yellow}--configs${normal} will list all repository config key/values. ${yellow}--show${normal} or ${yellow}--settings${normal} can be used as well. \n"
        printf "  ${green}$func${normal} ${yellow}--show${normal} or ${yellow}--settings${normal} can be used as well. \n"
        return
    fi
    if [ "$skip_init_feature" ];then
        return
    fi    

    if [ ! "$upstream_url" ]; then
        upstream_url="$1"
        if [ ! "$upstream_url" ]; then
            upstream_url="$first_param"
        fi
    fi

    if [ "$1" = "-" ] || [ "$2" = "-" ] || [ "$upstream_url" = "-" ] || [ "$upstream_url" = "true" ]; then
        set_upstream "-"
        return
    fi
    if [ ! "$is_repo" ]; then
        local yes_no="yes"
        if [ ! "$silent" ]; then
            ask yes_no $yellow "The current directory does not seem to be a git repository\nWould you like to initialize the repository and merge the remote upstream (Yes/No)?" "-" "yes"
        fi
        if [ ! "$yes_no" = "yes" ]; then
            println_not_silent "Aborting" $yellow
            exit 0
        fi

        init_repo
        init_upstream_url
        fetch_upstream
        merge_upstream
        init_repo
        if [ "$merge" ]; then
            run_push=$force_push
        fi
    else
        init_upstream_url
        fetch_upstream
        if [ "$merge" ]; then
            merge_upstream
            run_push=$force_push
        fi
    fi

    git__setup_source_config

    if [ ! "$remote_origin" ]; then
        set_origin
        if [ ! "$run_push" ]; then
            fetch_origin
        fi
        println_not_silent "Initalization complete." $green
    fi

    if [ "$run_push" ]; then
        git_push
    fi

    if [ "$configs" ]; then
        git_config_command="git config -l"
        run_command --command-in-var git_config_command  --skip-error
    fi
}
