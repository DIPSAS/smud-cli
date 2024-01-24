#!/usr/bin/env bash

gitops_model__show_changes() 
{
    printf "${white}List changes in Gitops model:${normal}\n"
    has_changes_command="git log $git_range --max-count=1 --no-merges $diff_filter --pretty=format:1 -- $devops_model_filter"
    {
        if [ "$git_range" ]; then
            run_command has-gitops-changes --command-var=has_changes_command --return-var=has_changes --debug-title='Check if any changes on gitops-model'
        fi    
    } ||
    {
        has_changes=""
    }
    if [ ! "$has_changes" ]; then
        if [ ! "$is_smud_dev_repo" ] && [ ! "$installed_gitops" ]; then
            printf "${gray}No gitops-model changes found.${normal}\n"   
            return 
        fi
    fi

    gitops_model__show_changelog_file "git"
    gitops_model__list_files "git"
}

gitops_model__list_files()
{
    from="$1"
    if [ "$from" = "git" ]; then
        local context="Changed"
        if [ "$git_range" ]; then
            gitops_model__list_files_command="git --no-pager log  $git_range --name-only --pretty= -- :$devops_model_filter|sort -u"
        else
            echo "No revisions available to fetch $context GitOps-model files!"
        fi
    else
        local context="Current"
        gitops_model__list_files_command="git --no-pager ls-files -- $devops_model_filter"
    fi
        
    {
        if [ "$gitops_model__list_files_command" ]; then
            run_command list-gitops-files --command-var=gitops_model__list_files_command --return-var=changed_files --debug-title='Find all changed gitops-model files files'
        fi
    } || 
    {
        return
    }

    if [ "$changed_files" ]; then
        echo "$context GitOps-model files:"
        echo $changed_files
    else
        echo "No $context GitOps-model files found!"
    fi
    
    echo ""
}

gitops_model__show_changelog_file()
{
    from="$1"
    if [ "$from" = "git" ]; then
        revisions=$git_range
        if [ ! "$revisions" ]; then
            echo "No revisions available to fetch GitOps-model Changelog!"
            return
        fi
        local context="Latest"
        show_changelog_commit_command="git rev-list $revisions -1 -- :CHANGELOG.md"
        {
            run_command --show_changelog_commit --command-var show_changelog_commit_command --return changelog_commit
            if [ "$changelog_commit" ]; then
                show_changelog_command="git show $changelog_commit:CHANGELOG.md"
            fi
        } || {
            show_changelog_command=""
        }
    else
        local context="Current"
        BASEDIR=$(dirname "$0")
        file=$BASEDIR/CHANGELOG.md
        if [ -f $file ]; then
            show_changelog_command="cat $file"
        fi
    fi

    if [ "$show_changelog_command" ]; then
        run_command --show_changelog --command-var show_changelog_command --return changelog_content
    fi

    if [ "$changelog_content" ]; then     
        print "$context GitOps-model Changelog:"
        echo $changelog_content
        IFS=$'\n';read -rd '' -a changelog_commits <<< "$changelog_commits"

        for commit in "${changelog_commits[@]}"
        do 
            git show $commit:CHANGELOG.md --no-color
        done
    else
        print "No $context GitOps-model Changelog found!"
    fi
    echo ""
}
