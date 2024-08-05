#!/bin/bash

source ADMIN_API_ACTIONS.sh # $ADMIN_API_ACTIONS

# export API keys

roles_info=$(mongosh --port 27017 --quiet --eval "use admin" --eval "db.getRoles({showPrivileges:true})" --json)
roles=$(echo "$roles_info" | jq -c '.roles[]')

for role in $roles; do
    privileges=$(echo "$role" | jq -c '.privileges[]')
    
    actions_payload='[]'

    for privilege in $privileges; do
        resource=$(echo "$privilege" | jq '[{cluster: false} + .resource]') # address cluster field
        
        actions=$(echo "$privilege" | jq -c '.actions[]')

        supported_actions=()
        
        for action in $actions; do
            action_formatted=$(echo "$action" | sed 's/\([A-Z]\)/_\1/g' | tr '[:lower:]' '[:upper:]' | sed 's/^_//' | jq -r)

            if printf '%s\n' "${ADMIN_API_ACTIONS[@]}" | fgrep -wq "$action_formatted"; then
                supported_actions+=("$action_formatted")
            else
                echo "Array element $action_formatted does not exist"
            fi
        done

        for action in "${supported_actions[@]}"; do
            actions_payload=$(echo "$actions_payload" | jq --arg action "$action" --argjson resource "$resource" '. += [{"action": $action, "resources": $resource}]')
        done
    done

    inheritedRoles_payload=$(echo $role | jq '.inheritedRoles')
    roleName_payload=$(echo "$role" | jq -r '.role')
    
    # Format payload    
    payload=$(jq -n \
        --argjson actions_api "$actions_payload" \
        --argjson inheritedRoles_api "$inheritedRoles_payload" \
        --arg roleName_api "$roleName_payload" \
        '{actions: $actions_api, inheritedRoles: $inheritedRoles_api, roleName: $roleName_api}')

    # echo "${payload}" | jq 

    # Create custom role
    curl --user "$PUBLIC_KEY:$PRIVATE_KEY" \
         --digest \
         --header "Accept: application/vnd.atlas.2023-01-01+json" \
         --header "Content-Type: application/json" \
         --data "$payload" \
         -X POST "https://cloud.mongodb.com/api/atlas/v2/groups/$DEST_GROUP_ID/customDBRoles/roles"
done
