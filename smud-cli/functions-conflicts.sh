print_verbose "**** START: functions-conflicts.sh"

conflicts()
{
    if [ "$help" ]; then
        echo "${bold}smud conflict(s)${normal} [options]: List conflicts in yaml-files or resolve conflicts in conflictiong files."
        echo ""
        echo "Options:"
        echo "  <no-options>: Scan and list conflicts in yaml-files."
        echo "  --merge-ours=, --ours:"
        echo "      Merge conflicts with our versions"
        echo "  --merge-theirs=, --theirs:"
        echo "      Merge conflicts with their versions"
        echo "  --merge-union=, --union:"
        echo "      Merge conflicts with union versions"

    fi
    
    exit_if_is_not_a_git_repository

    if [ "$merge_ours" ]; then
        if [ ! "$conflicts_files" ]; then
            conflicts_files=$(git-list-conflict 'files')
        fi
        printf "${white}Resolve conflicts based on ours version.\n"
        for file in $conflicts_files;do
            git-resolve-conflict "--ours" "$file"
        done
    elif [ "$merge_theirs" ]; then
        if [ ! "$conflicts_files" ]; then
            conflicts_files=$(git-list-conflict 'files')
        fi
        printf "${white}Resolve conflicts based on their version.\n"
        for file in $conflicts_files;do
            git-resolve-conflict "--theirs" "$file"
        done
    elif [ "$merge_union" ]; then
        if [ ! "$conflicts_files" ]; then
            conflicts_files=$(git-list-conflict 'files')
        fi
        printf "${white}Resolve conflicts based on union version.\n"
        for file in $conflicts_files;do
            git-resolve-conflict "--union" "$file"
        done
    else
        git-list-conflict
    fi

}
git-list-conflict() {
    if [ "$1" == "files" ]; then
        sh -c "find $find_files_filter -name '*.yaml' -exec grep -H -e '>>>' -e '<<<' {} \;" | awk --field-separator=: '{ print $1}'|uniq
        return
    fi

    printf "${white}Scan and list conflicts in yaml-files.\n"
    
    sh -c "find $find_files_filter -name '*.yaml' -exec grep -H -e '>>>' -e '<<<' {} \;"
}

git-resolve-conflict() {
  STRATEGY="$1"
  FILE_PATH="$2"
  if [ -z "$FILE_PATH" ] || [ -z "$STRATEGY" ]; then
    echo "Usage:  smud conflicts <strategy> <file>"
    echo ""
    echo "Example: git-resolve-conflict --ours package.json"
    echo "Example: git-resolve-conflict --union package.json"
    echo "Example: git-resolve-conflict --theirs package.json"
    return
  fi

  if [ ! -f "$FILE_PATH" ]; then
    echo "$FILE_PATH does not exist; aborting."
    return
  fi

  # remove leading ./ if present, to match the output of git diff --name-only
  # (otherwise if user input is './filename.txt' we would not match 'filename.txt')
  FILE_PATH_FOR_GREP=${FILE_PATH#./}
  # grep -Fxq: match string (F), exact (x), quiet (exit with code 0/1) (q)
  if ! git diff --name-only --diff-filter=U | grep -Fxq "$FILE_PATH_FOR_GREP"; then
    echo "$FILE_PATH is not in conflicted state; aborting."
    return
  fi

  git show :1:"$FILE_PATH" > ./tmp.common
  git show :2:"$FILE_PATH" > ./tmp.ours
  git show :3:"$FILE_PATH" > ./tmp.theirs

  git merge-file "$STRATEGY" -p ./tmp.ours ./tmp.common ./tmp.theirs > "$FILE_PATH"
  git add "$FILE_PATH"

  rm ./tmp.common
  rm ./tmp.ours
  rm ./tmp.theirs
}



print_verbose "**** END: functions-conflicts.sh"