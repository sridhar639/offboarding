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




list() {
SEARCH="cdw"

assume_role "112393354275" "CDWMasterOrgAdminRole"

echo "============================= Lambda Functions ==================================================="
aws lambda list-functions --query "Functions[].FunctionName" --output text | tr '\t' '\n' | grep -i "$SEARCH"

echo "=== CloudFormation Stacks ==================================================="
aws cloudformation list-stacks \
  --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
  --query "StackSummaries[].StackName" --output text | tr '\t' '\n' | grep -i "$SEARCH"

echo "============================= CloudFormation StackSets ==================================================="
aws cloudformation list-stack-sets --status ACTIVE \
  --query "Summaries[].StackSetName" --output text | tr '\t' '\n' | grep -i "$SEARCH"

echo "============================= IAM Roles ==================================================="
aws iam list-roles --query "Roles[].RoleName" --output text | tr '\t' '\n' | grep -i "$SEARCH"

echo "============================= IAM Policies ==================================================="
aws iam list-policies --scope Local \
  --query "Policies[].PolicyName" --output text | tr '\t' '\n' | grep -i "$SEARCH"

echo "============================= S3 Buckets ==================================================="
aws s3api list-buckets --query "Buckets[].Name" --output text | tr '\t' '\n' | grep -i "$SEARCH"

}