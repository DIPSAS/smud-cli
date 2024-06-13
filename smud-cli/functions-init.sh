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
        remove_upstream_command="git remote rm upstream"
        run_command remove-upstream --command-from-var=remove_upstream_command --debug-title='Removing upstream config URL'
        if [ "$new_upstream" = "-" ]; then
            println_not_silent "Upstream is removed" $gray
            exit
        else
            add_upstream_command="git remote add upstream $new_upstream"
            run_command add_upstream_command --command-from-var=add_upstream_command --debug-title='Adding upstream with user specified URL'
            println_not_silent "Upstream configured with '$new_upstream' " $gray
        fi
    elif [ ! "$new_upstream" ]; then
        new_upstream="$default_upstream"
        add_upstream_command="git remote add upstream $new_upstream"
        run_command add_upstream_command --command-from-var=add_upstream_command --debug-title='Adding upstream with default URL'
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
    check_origin_command="git config --get remote.origin.url"
    run_command --check-origin --command-from-var=check_origin_command --return-var=remote_origin --debug-title='Checking if remote.origin.url exist in git config'
    # If string is empty, set the remote origin url
    if [ ! "$remote_origin" ]; then
        ask remote_origin $yellow "Remote repository origin is not set, please enter URL for the remote origin.\nOrigin URL:" "true"
        if [ "$remote_origin" ]; then
            add_origin_command="git remote add origin $remote_origin"
            run_command --set-origin --command-from-var=add_origin_command --return-var=dummy --debug-title='Adding remote origin' || return
        fi
    fi
}

merge_upstream()
{
    if [ "$skip_init_feature" ];then
        return
    fi    

    if [ "$skip_auto_update" ]; then
        return
    fi
    println_not_silent "Merging upstream into local branch..." $gray
    merge_upstream_command="git merge upstream/main"
    run_command merge-upstream --command-from-var=merge_upstream_command --return-var=dummy --debug-title='Merging upstream repository into local branch' || return
    
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

    println_not_silent "Fetching origin..." $gray  
    fetch_origin_command="git fetch origin"
    run_command fetch-origin --command-from-var=fetch_origin_command --return-var=dummy --debug-title='Fetching origin' || return
} 

init_repo()
{
    init_command="git init"
    if [ "$skip_init_feature" ];then
        return
    fi    
    if [ ! "$is_repo" ];then
        run_command init-repo --command-from-var=init_command --return-var=dummy --debug-title='Initializing repository' || return
        is_repo="true"

        branches="$(git branch)"
        if [ ! -n "$branches" ]; then
            # "main" possibly not default branch name so create it
            create_main_branch="git checkout -b main"
            run_command checkout-main --command-from-var=create_main_branch --return-var=dummy --debug-title='Creating main branch' || return
        fi 
    fi
    git__setup 'true'
}

fetch_upstream()
{
    if [ "$skip_init_feature" ];then
        return
    fi    

    fetch_upstream_command="git fetch upstream"
    run_command fetch-upstream --command-from-var=fetch_upstream_command --return-var=dummy --debug-title='Fetching upstream' || return
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
            ask yes_no $yellow "The current directory does not seem to be a git repository\nWould you like to initialize the repository and merge the remote upstream? (yes/no)"
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
    else
        init_upstream_url
        fetch_upstream
    fi

    if [ "$is_repo" ]; then
        
        if [ ! "$source_branch" ]; then
            
            if [ "$current_branch" ]; then    
                source_branch="$(git config --get source.$current_branch)"
            fi
        fi
        

        if [ ! "$source_branch" ]; then
            source_branch="upstream/$default_branch"
        fi

        
        old=""
        if [ "$current_branch" ]; then    
            old="$(git config --get source.$current_branch)"
        fi
        
        if [ ! "$old" = "$source_branch" ] || [ ! "$old" ] ; then

            if [ "$old" ] && [ "$current_branch" ]; then
                dummy="$(git config --unset source.$current_branch)"
            fi
            
            if [ "$current_branch" ] && [ "$source_branch" ]; then
                dummy="$(git config --add source.$current_branch $source_branch)"
            fi
        fi
    fi


    if [ ! "$remote_origin" ]; then
        println_not_silent "Setting and fetching origin" $gray
        set_origin
        fetch_origin
        println_not_silent "Initalization complete." $green
    fi

    if [ "$configs" ]; then
        config_command="git config -l"
        run_command config-list --command-var config_command  --skip-error
    fi
}
