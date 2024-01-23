#!/usr/bin/env bash

show_gitops_changes() 
{
    printf "${white}List changes in Gitops model:${normal}\n"
    has_changes_command="git log $git_range --max-count=1 --no-merges $git_grep $diff_filter --pretty=format:1 -- $devops_model_filter"
    {
        if [ "$git_range" ]; then
            run_command has-gitops-changes --command-from-var=has_changes_command --return-in-var=has_changes --debug-title='Check if any changes on gitops-model'
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

    show_changelog_file "git"
    list_gitops_files "git"
}

list_gitops_files()
{
    from="$1"
    if [ "$from" = "git" ]; then
        context="Changed"
        if [ "$git_range" ]; then
            list_gitops_files_command="git --no-pager log  $git_range --name-only --pretty= -- :$devops_model_filter|sort -u"
        else
            echo "No revisions available to fetch $context GitOps-model files!"
        fi
    else
        context="Current"
        list_gitops_files_command="git --no-pager ls-files -- $devops_model_filter"
    fi
        
    {
        if [ "$list_gitops_files_command" ]; then
            run_command list-gitops-files --command-var=list_gitops_files_command --return=changed_files --debug-title='Find all changed gitops-model files files'
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

show_changelog_file()
{
    from="$1"
    if [ "$from" = "git" ]; then
        revisions=$git_range
        if [ ! "$revisions" ]; then
            echo "No revision"
            return
        fi
        context="Latest"
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
        context="Current"
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
        IFS=$'\n' read -rd '' -a changelog_commits <<< "$changelog_commits"

        for commit in "${changelog_commits[@]}"
        do 
            git show $commit:CHANGELOG.md --no-color
        done
    else
        print "No $context GitOps-model Changelog found!"
    fi
    echo ""
}
