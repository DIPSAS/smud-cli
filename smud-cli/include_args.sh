#!/usr/bin/env bash

if [ "$_" = "/usr/bin/sh" ] || [ "$_" = "/bin/sh" ]; then
    echo "Native '$_' not supported here :-("
    echo "Please run this inside bash!"
    exit
fi

parse_arguments()
{   
    local old_SEP=$IFS
    local -n parse_arguments_args="$1"
    # echo "0.str: $@"
    if [ $# -gt 0 ];then
        has_args="true"
        local str="$(echo " $@"|sed -e 's/--/-_sep_/g' |sed -e 's/ -/§/g')"
        # echo "str: $str"
        IFS="§"; read -ra array <<< " $str";
        local c=$(echo "${array[0]}" | grep '-' -c)
        if [ $c -eq 0 ]; then
            shift
            if [ $# -eq 0 ];then
                IFS=$old_SEP
                return
            fi
            local str="$(echo " $@"|sed -e 's/--/-_sep_/g' |sed -e 's/ -/§/g')"
            # echo "str: $str"
            IFS="§"; read -ra array <<< " $str";
        fi
        # echo "str: $str"
        # echo "array: ${array[@]}"
        for s in "${array[@]}"
        do
            # echo "0:s: $s"
            if [ ! "$s" ] || [ "$s" = " " ]; then
                continue
            fi
            local s="$(echo "$s"|xargs -d ' '| tr -d '\n')"
            # echo "s: $s"
            local s="$(echo "-$s" |sed -e 's/_sep_/-/g')"
            # echo "s: $s"
            arg=()
            if [ $(grep '=' -c <<< $s) -gt 0 ]; then
                IFS='='; read -ra arg <<< "$s"
                # echo "eq.arg: { key: ${arg[0]}, value: ${arg[1]} }"
            else
                IFS=' '; read -ra arg_ <<< "$s"
                arg[0]="${arg_[0]}"
                arg[1]="${arg_[@]:1}"
                # echo "space.arg: { key: ${arg[0]}, value: ${arg[1]} }"
            fi
            # echo "%%%  ${arg[@]}"

            local key="${arg[0]}"
            # echo "key: $key"
            if [ ! "$key" = "-n" ]; then
                local key="$(echo "${arg[0]}"|xargs -d ' '| tr -d '\n')"
            fi
            local value="${arg[1]}"
            # echo "key: $key, value: $value"

            if [ ! "$value" ]; then
                local c=$(echo "$s" | grep ' ' -c)
                if [ $c -gt 0 ]; then
                    IFS=' ';read -ra arg <<< "$s"
                    local key="$(echo "${arg[0]}")"
                    local value="$(echo "$s"|sed -e "s/$key //g"|xargs -d ' '| tr -d '\n')"
                fi
            fi
            local value="${value:-true}"
            if [ "$key" ]; then
                if [ "$key" != "-n" ]; then
                    key="$(echo "$key"|sed -e "s/---/--/g"|xargs -d ' '| tr -d '\n')"
                fi
                if [ "$key" != "-" ]; then
                    local value=$(echo "$value"|xargs -d ' '| tr -d '\n')
                    old_value=${parse_arguments_args["$key"]}
                    if [ "$old_value" != "$value" ]; then
                        if [ "$old_value" ] && [ "$value" != "true" ]; then
                            if [ ! "$argument_single_mode" ] && [ "$value" ]; then
                                value="$old_value,$value"
                            else
                                value="$old_value"
                            fi
                        fi
                        # if [ "$old_value" ]; then
                        #     print_gray "old_value: [$old_value], value: [$value]"
                        # fi

                        parse_arguments_args["$key"]="$value"
                    fi
                fi
            fi
        done
    fi

    get_arg verbose '--verbose'
    if [ "$verbose" ]; then
        debug="true"
        for key in "${!parse_arguments_args[@]}"; 
        do 
            key="${key}"
            value="${parse_arguments_args[${key}]}"
        done
    fi
    IFS=$old_SEP
}

get_arg()
{
    local -n value="$1"
    local old_SEP=$IFS
    local global="true"
    if [ "$4" ];then
        local -n get_arg_args="$4"
    fi

    if [ "$5" ];then
        local global="$5"
    fi

    if [ "$global" != "true" ]; then
        value=""
    fi
    
    # echo "keys: $2"
    IFS=","; read -ra keys <<< "$2";
    for key in "${keys[@]}"
    do
        if [ ! "$key" = "-n" ]; then
            key="$(echo "$key"|xargs -d ' '| tr -d '\n')" 
        fi
        key_value=""
        if [ ! "$4" ];then
            key_value="${ARGS[$key]}"
        else
            key_value="${get_arg_args[$key]}"
        fi
        if [ "$key_value" ]; then
            if [ ! "$argument_single_mode" ] && [ "$value" ] && [ "$value" != "true" ];then
                value="$value,$key_value"
            else
                value="$key_value"
            fi
        fi
    done

    if [ ! "$value" ] && [ "$3" ]; then
        value="$3"
    fi
    IFS=$old_SEP
    if [ "$value" ] && [ "$1" != "debug" ] && [ "$1" != "verbose" ];  then
        if [ "$global" == "true" ]; then
            print_verbose_args "Loaded argument $1:'$value'"
        fi
    fi
}
print_verbose_args() 
{
    if [ "$verbose" ]; then
        if [ "$1" ]; then
            printf "\x1b[1;90m$1$(tput sgr0)\n"
        else
            echo ""
        fi
    fi
}

if [ ! "$include_args_loaded" ]; then
    declare -A ARGS

    first_param="$3"
    if [ "$startup_shift" ]; then
        shift
    fi

    parse_arguments ARGS $@
    
    get_arg silent '--silent'
    get_arg verbose '--verbose'
    get_arg debug '--debug' "$verbose"
    
    IFS=$'\n'
    include_args_loaded="true"
fi