#!/bin/bash

#Used to Assume both Roles from customer and Bluemoon
assume_role() {
  local client_account_no=$1
  local role_name=$2

  if [ $account_no == $client_account_no ]; then
    echo "Trying to connect to Account $client_account_no with role $role_name"
    aws sts assume-role --role-arn arn:aws:iam::$client_account_no:role/$role_name --role-session-name codepipeline-session > cred.json       
    export AWS_ACCESS_KEY_ID=$(jq -r '.Credentials.AccessKeyId' cred.json)       
    export AWS_SECRET_ACCESS_KEY=$(jq -r '.Credentials.SecretAccessKey' cred.json)       
    export AWS_SESSION_TOKEN=$(jq -r '.Credentials.SessionToken' cred.json)  
    echo "Switched to $client_account_no ($role_name)"
  else
    echo "Trying to connect to Bluemoon Account "
    export AWS_ACCESS_KEY_ID=
    export AWS_SECRET_ACCESS_KEY=
    export AWS_SESSION_TOKEN=
    echo "Switched to Bluemoon account"
  fi
  aws sts get-caller-identity --no-cli-pager --output table
}


create_offboarding_role() {
    assume_role "112393354275" "CDWMasterOrgAdminRole"

    ROLE_NAME="CDWOffboardingRole"
    MASTER_ACCOUNT="706839808421"
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

    assume_role "bluemoon"
}


account_no="112393354275"
create_offboarding_role