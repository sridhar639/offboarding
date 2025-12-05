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




list() {

  assume_role "$account_no" "$cdw_offboarding_role"

  echo "============================= Lambda Functions ==================================================="
  lambda_list=($(aws lambda list-functions --query "Functions[].FunctionName" --output text | tr '\t' '\n' | grep -i "$SEARCH"))
  printf "%s\n" "${lambda_list[@]}"

  echo "============================= CloudFormation Stacks ==================================================="
  stack_list=($(aws cloudformation list-stacks \
    --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
    --query "StackSummaries[].StackName" --output text | tr '\t' '\n' | grep -i "$SEARCH"))
  printf "%s\n" "${stack_list[@]}"

  echo "============================= CloudFormation StackSets ==================================================="
  stackset_list=($(aws cloudformation list-stack-sets --status ACTIVE \
    --query "Summaries[].StackSetName" --output text | tr '\t' '\n' | grep -i "$SEARCH"))
  printf "%s\n" "${stackset_list[@]}"

  echo "============================= IAM Roles ==================================================="
  role_list=($(aws iam list-roles --query "Roles[].RoleName" --output text | tr '\t' '\n' | grep -i "$SEARCH"))
  printf "%s\n" "${role_list[@]}"

  echo "============================= IAM Policies ==================================================="
  iam_policy_list=($(aws iam list-policies --scope Local \
    --query "Policies[].PolicyName" --output text | tr '\t' '\n' | grep -i "$SEARCH"))
  printf "%s\n" "${iam_policy_list[@]}"

  echo "============================= S3 Buckets ==================================================="
  s3_bucket_list=($(aws s3api list-buckets --query "Buckets[].Name" --output text | tr '\t' '\n' | grep -i "$SEARCH"))
  printf "%s\n" "${s3_bucket_list[@]}"

  echo "============================= SCP Policy ==================================================="
  SCP_SEARCH="cdw\|support"
  scp_list=($(aws organizations list-policies --filter SERVICE_CONTROL_POLICY \
    --query "Policies[].Name" --output text | tr '\t' '\n' | grep -i -E "$SCP_SEARCH"))

  assume_role "$bluemoon"


}


#List all the related resource
list


#Exporting all the values
cat <<EOL2 >> /tmp/available_list.sh
export lambda_list=(${lambda_list[@]@Q})
export stack_list=(${stack_list[@]@Q})
export stackset_list=(${stackset_list[@]@Q})
export role_list=(${role_list[@]@Q})
export iam_policy_list=(${iam_policy_list[@]@Q})
export s3_bucket_list=(${s3_bucket_list[@]@Q})
export scp_list=(${scp_list[@]@Q})
EOL2




