#!/usr/bin/env bash

init()
{
    if [ $help ]; then
        func=${1:-init}
        echo "${bold}smud $func${normal}: Fetch upstream"
        printf "With Only ${green}$func${normal}, Upstream '$default_upstream' will be configured if not configured yet. When configured the upstream will be fetched. \n"
        printf "With ${green}$func ${bold}<value>${normal}, Upstream '<value>' will be configured before upstream is fetched. \n"
        printf "With ${green}$func ${bold}-${normal}, Upstream will be removed. \n"
        return
    fi

    upstream
}