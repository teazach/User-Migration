#!/bin/bash

# export API keys
# export SOURCE and DEST group_ids

# Check commands are present, 'which jq'
# Error handling

# Reset credentials file
current_date_time=$(date +"%Y-%m-%d_%H-%M-%S")
file="${PWD}/${current_date_time}_user_credentials.csv"

if [ -f "$file" ]; then
    echo "true"
    rm "$file"
fi

echo $file

echo "Username, Password" >> "$file"

output=$(curl --user "$PUBLIC_KEY:$PRIVATE_KEY" \
  --digest \
  --header "Accept: application/vnd.atlas.2024-05-30+json" \
  -X GET "https://cloud.mongodb.com/api/atlas/v2/groups/$SOURCE_GROUP_ID/databaseUsers")
echo $output

num_users=$(echo "$output" | jq -r '.results | length')

for ((i=0; i<num_users; i++)); do
    # awsIAMType
    # databaseName
    # groupId
    # labels
    # ldapAuthType
    # links
    # oidcAuthType
    # roles
    # scopes
    # username
    # x509Type

    databaseName=$(echo "$output" | jq -r ".results[$i].databaseName")
    groupId=$(echo "$output" | jq -r ".results[$i].groupId")
    password="test_password"
    roles=$(echo "$output" | jq -r ".results[$i].roles | tojson")
    scopes=$(echo "$output" | jq -r ".results[$i].scopes | tojson")
    username=$(echo "$output" | jq -r ".results[$i].username")"-generated"

    # echo "User $((i+1)):"
    # echo "Database Name: $databaseName"
    # echo "Group ID: $groupId"
    # echo "Password: $password"
    # echo "Roles: $roles"
    # echo "Scopes: $scopes"
    # echo "Username: $username"
    # echo "----------------------"

    # Format payload    
    payload=$( jq -n \
                  --arg dbn "$databaseName" \
                  --arg gid "$groupId" \
                  --arg pw "$password" \
                  --argjson rls "$roles" \
                  --argjson scps "$scopes" \
                  --arg us "$username" \
                  '{databaseName: $dbn, groupId: $gid, password: $pw, roles: $rls, scopes: $scps, username: $us}' )

    echo "$username, $password" >> "$file"

    echo "${payload}" | jq

    curl --user "$PUBLIC_KEY:$PRIVATE_KEY" \
    --digest \
    --header "Accept: application/vnd.atlas.2023-01-01+json" \
    --header "Content-Type: application/json" \
    --data "$payload" \
    -X POST "https://cloud.mongodb.com/api/atlas/v2/groups/$DEST_GROUP_ID/databaseUsers"
done
