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

#Check current stack Progress
monitor_stack() {
  local stack_name=$1

  while :
  do
     cf_status=$(aws cloudformation describe-stacks --stack-name "$stack_name" --query "Stacks[0].StackStatus" --output text)
     echo "$stack_name status: $cf_status"
     if [[ $cf_status == "DELETE_COMPLETE" ]]; then
        echo "Successfully Deleted $stack_name"
     elif [[ $cf_status == "DELETE_IN_PROGRESS" ]]; then
        sleep 10
     elif [[ $cf_status == "ROLLBACK_IN_PROGRESS" || $cf_status == "ROLLBACK_COMPLETE" ]]; then
        END_TS=$(date "+ %d/%m/%Y:%H:%M:%S")
        error_message=$(get_stack_failure_reason "$stack_name")
        echo "$error_messages"
     fi
  done
}


delete_cdw_resources() {
    assume_role "112393354275" "CDWOffboardingRole"

    echo "Deleting Stacks"
    for stack in "${stack_list[@]}"; do
        echo "Deleting stack: $stack"
        aws cloudformation delete-stack --stack-name "$stack"
        monitor_stack "$stack"
    done

    assume_role "bluemoon"
}


account_no="112393354275"
delete_cdw_resources