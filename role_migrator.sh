#!/bin/bash

source ADMIN_API_ACTIONS.sh # $ADMIN_API_ACTIONS

# export env variables

roles_info=$(mongosh --port 27017 --quiet --eval "use admin" --eval "db.getRoles({showPrivileges:true})" --json)
roles=$(echo "$roles_info" | jq -c '.roles[]')

for role in $roles; do
    privileges=$(echo "$role" | jq -c '.privileges[]')
    
    all_actions=()
    
    for privilege in $privileges; do
        actions=$(echo "$privilege" | jq -c '.actions[]')
        for action in $actions; do
            all_actions+=("$action")
        done
    done

    unique_actions=($(echo "${all_actions[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

    actions_payload='[]'

    for action in "${unique_actions[@]}"; do
        action_formatted=$(echo "$action" | sed 's/\([A-Z]\)/_\1/g' | tr '[:lower:]' '[:upper:]' | sed 's/^_//' | jq -r)
        
        # 0: unsupported
        if [[ $(printf '%s\n' "${ADMIN_API_ACTIONS[@]}" | fgrep -wq "$action_formatted"; echo $?) -eq 1 ]]; then
            # echo "$action action is not supported"
            continue
        fi

        # 1: supported
        # echo "$action action is supported"
        actions_with_privileges="{\"action\": \"$action_formatted\", \"resources\": []}"

        for privilege in $privileges; do
            # TODO: if not supported by database/colleciton skip
            privilege_actions=$(echo "$privilege" | jq -c '.actions[]')
            resource=$(echo "$privilege" | jq '{cluster: false} + .resource') # fix cluster field

            if printf '%s\n' "${privilege_actions[@]}" | fgrep -wq "$action"; then
                actions_with_privileges=$(echo "$actions_with_privileges" | jq --argjson resource "$resource" '.resources += [$resource]')
            fi
        done

        actions_payload=$(echo "$actions_payload" | jq --argjson action_with_privileges "$actions_with_privileges" '. += [$action_with_privileges]')
    done

    inheritedRoles_payload=$(echo $role | jq '.inheritedRoles')
    roleName_payload=$(echo $role | jq -r '.role')
    
    # echo $actions_payload | jq .
    # echo $inheritedRoles_payload | jq .
    # echo $roleName_payload
        
    # Format payload    
    payload=$(jq -n \
        --argjson actions_api "$actions_payload" \
        --argjson inheritedRoles_api "$inheritedRoles_payload" \
        --arg roleName_api "$roleName_payload" \
        '{actions: $actions_api, inheritedRoles: $inheritedRoles_api, roleName: $roleName_api}')

    echo $payload | jq .

    curl --user "$PUBLIC_KEY:$PRIVATE_KEY" \
        --digest \
        --header "Accept: application/vnd.atlas.2023-01-01+json" \
        --header "Content-Type: application/json" \
        --data "$payload" \
        -X POST "https://cloud.mongodb.com/api/atlas/v2/groups/$DEST_GROUP_ID/customDBRoles/roles"
done
