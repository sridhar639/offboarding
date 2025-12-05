#!/bin/bash


#Getting requiring variables from get-variable generated file
if [ -f /tmp/build_vars.sh ]; then
    source /tmp/build_vars.sh
else 
    echo "Build variables not found! Did pre-build succeed?"
    exit 1
fi


#Used to Assume both Roles from customer and Bluemoon
assume_role() {
  local client_account_no=$1
  local role_name=$2

  if [ $account_no == $client_account_no ]; then
    echo "Trying to connect to Account $client_account_no with role $role_name"
    if ! aws sts assume-role \
     --role-arn arn:aws:iam::$client_account_no:role/$role_name \
     --role-session-name codepipeline-session > cred.json; then    
     echo "Error: Failed to assume role $role_name in $client_account_no"
     exit 1
    fi

    export AWS_ACCESS_KEY_ID=$(jq -r '.Credentials.AccessKeyId' cred.json)       
    export AWS_SECRET_ACCESS_KEY=$(jq -r '.Credentials.SecretAccessKey' cred.json)       
    export AWS_SESSION_TOKEN=$(jq -r '.Credentials.SessionToken' cred.json)  
    echo "Switched to $client_account_no ($role_name)"
  elif [ "bluemoon" == "${client_account_no,,}" ]; then
    echo "Trying to connect to Bluemoon Account "
    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
    echo "Switched to Bluemoon account"
  else
    echo "Unable to switch Role"
    exit 1
  fi
}
 

create_offboarding_role() {
    assume_role "$account_no" "$cdw_master_org_role"

    ROLE_NAME="$cdw_offboarding_role"
    MASTER_ACCOUNT="$bluemoon_account"
    POLICY_ARN="arn:aws:iam::aws:policy/AdministratorAccess"

    # Trust policy as variable (HEREDOC must NOT be indented)
    TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${MASTER_ACCOUNT}:root"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
)

    echo "Creating IAM Role: $ROLE_NAME"

    aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document "$TRUST_POLICY" \
        --path "/" >/dev/null

    echo "Attaching AdministratorAccess policy..."

    aws iam attach-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-arn "$POLICY_ARN" >/dev/null

    echo "Role $ROLE_NAME created successfully with Admin access."
    sleep 5

    assume_role "$bluemoon"
}



create_offboarding_role