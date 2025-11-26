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

assume_role "112393354275" "CDWOffboardingRole"

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

assume_role "bluemoon"

}



account_no="112393354275"
list


#Exporting all the values
cat <<EOL >> /tmp/build_vars.sh
export lambda_list=(${lambda_list[@]@Q})
export stack_list=(${stack_list[@]@Q})
export stackset_list=(${stackset_list[@]@Q})
export role_list=(${role_list[@]@Q})
export iam_policy_list=(${iam_policy_list[@]@Q})
export s3_bucket_list=(${s3_bucket_list[@]@Q})
export scp_list=(${scp_list[@]@Q})
EOL


echo -e "\nWrote Everything to /tmp/build_vars.sh"
echo "================ File Contents ================"
cat /tmp/build_vars.sh
echo "==============================================="

