print_verbose "**** START: functions-resources.sh"

resources()
{
    if [ "$help" ]; then
        echo "${bold}smud resource(s)${normal}: Show all used resources for selected context.."
        return
    fi
    ns_col=""
    ns_title=" for namespace ${blue}'$namespace'${white}"
    exclude_ns=""
    if [ ! "$namespace" ]; then
        ns_col="NAMESPACE:.metadata.namespace,"
        ns_title=" for ${blue}all${white} namespaces"
        exclude_ns="--field-selector 'metadata.namespace!=kube-system,metadata.namespace!=longhorn-system,metadata.namespace!=longhorn-system' "
    fi

    printf "${white}Show all used resources${ns_title} in context: ${blue}'$(kubectl config current-context)'${normal}.\n${normal}"

    pods_command="kubectl get pods ${namespace_filter} ${exclude_ns} --sort-by=.spec.containers[].resources.requests.cpu -o custom-columns=NAME:.metadata.name,${ns_col}REQ-CPU:.spec.containers[].resources.requests.cpu,REQ-MEM:.spec.containers[].resources.requests.memory,INIT-REQ-CPU:.spec.initContainers[].resources.requests.cpu,INIT-REQ-MEM:.spec.initContainers[].resources.requests.memory,OWNER-KIND:.metadata.ownerReferences[].kind,OWNER-NAME:.metadata.ownerReferences[].name |sed -e 's/<none>/      /g'"
    cronjobs_command="kubectl get cj ${namespace_filter} --sort-by=.spec.jobTemplate.spec.template.spec.containers[].resources.requests.cpu -o custom-columns=NAME:.metadata.name,${ns_col}REQ-CPU:.spec.jobTemplate.spec.template.spec.containers[].resources.requests.cpu,REQ-MEM:.spec.jobTemplate.spec.template.spec.containers[].resources.requests.memory |sed -e 's/<none>/      /g'"
    
    run_command --command-var=pods_command --return-var=lines_array --array --force-debug-title 'Pod resources'
    old_SEP=$IFS
    
    IFS=$'\n'
    if [ ${#lines_array[@]} -gt 1 ]; then
        echo "Pods:"
        header="${lines_array[0]}"
        printf "${white}$header${normal}\n"
        echo "${lines[@]}" | tail +2|tac
    fi

    run_command --command-var=cronjobs_command --return-var=cron_lines_array --array --force-debug-title 'Cronjob resources'
    
    IFS=$'\n'
    if [ ${#cron_lines_array[@]} -gt 1 ]; then
        printf "\nCronJobs:\n"
        header="${cron_lines_array[0]}"
        printf "${white}$header${normal}\n"
        echo "${cron_lines[@]}" | tail +2|tac
    fi
    IFS=$old_SEP
}

print_verbose "**** END: functions-resources.sh"