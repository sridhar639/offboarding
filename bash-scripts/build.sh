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




delete_cdw_resources() {
    assume_role "112393354275" "CDWOffboardingRole"

    echo "Deleting Stacks"
    for stack in "${stack_list[@]}"; do
        echo "Deleting stack: $stack"
        aws cloudformation delete-stack --stack-name "$stack"
    done

    assume_role "bluemoon"
}


account_no="112393354275"
delete_cdw_resources