#!/usr/bin/env bash
if [ ! "$smud_main_loaded" ]; then

    smud_main_loaded="true"
    . $(dirname "$0")/include.sh "$@"

    print_verbose "**** START: smud-main.sh"
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
    get_arg force_push '--push,--force-push'
    get_arg skip_files '--skip-files,--no-files'
    get_arg show_files '--show-files,--files'
    get_arg responsible '--responsible,--team'
    get_arg conflicts_files '--conflict-files,--files'
    get_arg merge_ours '--merge-ours,--our,--ours'
    get_arg merge_theirs '--merge-theirs,--their,--theirs'
    get_arg merge_union '--merge-union,--union'
    get_arg merge '--merge'
    get_arg namespace '--namespace,-N,-n'
    get_arg development '--development,-D,-DEV,--DEV'
    get_arg external_test '--external-test,-ET,--ET'
    get_arg internal_test '--internal-test,-IT,--IT'
    get_arg production '--production,-PROD,--PROD'
    get_arg stage '--stage,-S' '**'

    if [ "$responsible" ];then
        responsible="$(sed -E 's/(,| |;)/|/g' <<< $responsible)"
    fi
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
    print_verbose "**** END: smud-main.sh"
fi