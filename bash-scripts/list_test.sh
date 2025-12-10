#!/bin/bash

SEARCH="cdw"
ACCOUNT_LIST_BUCKET="sri-test-offboarding"
ACCOUNT_LIST_KEY="clean_accounts.csv"
OUTPUT_BUCKET="test-offboarding"
OUTPUT_KEY="resource-inventory/resources.csv"

TEMP_ACCOUNTS=$(mktemp)
TEMP_CSV=$(mktemp)


echo "Account,Region,ResourceType,ResourceName" > "$TEMP_CSV"

#############################################
### 1. Download CSV With Only Account Numbers
#############################################
aws s3 cp "s3://${ACCOUNT_LIST_BUCKET}/${ACCOUNT_LIST_KEY}" "$TEMP_ACCOUNTS"

#############################################
### 2. Read account numbers (each line is one)
#############################################
dos2unix "$TEMP_ACCOUNTS" 2>/dev/null || sed -i 's/\r$//' "$TEMP_ACCOUNTS"
mapfile -t account_numbers < "$TEMP_ACCOUNTS"
# Print loaded accounts
echo "Loaded accounts:"
printf '%s\n' "${account_numbers[@]}"
# Write CSV Header

assume_role() {
  local client_account_no=$1
  local role_name=$2

  if [ "$account_no" == "$client_account_no" ]; then
    echo "Trying to connect to Account $client_account_no with role $role_name"

    if ! aws sts assume-role \
       --role-arn arn:aws:iam::$client_account_no:role/$role_name \
       --role-session-name codepipeline-session > cred.json; then    
       echo "Error: Failed to assume role"
       exit 1
    fi

    export AWS_ACCESS_KEY_ID=$(jq -r '.Credentials.AccessKeyId' cred.json)
    export AWS_SECRET_ACCESS_KEY=$(jq -r '.Credentials.SecretAccessKey' cred.json)
    export AWS_SESSION_TOKEN=$(jq -r '.Credentials.SessionToken' cred.json)

  elif [ "706839808421" == "${client_account_no}" ]; then
    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
  else
    exit 1
  fi
}

append_csv() {
  local region=$1
  local type=$2
  local name=$3

  echo "$account_no,$region,$type,$name" >> "$TEMP_CSV"
}

list() {
    for account_no in "${account_numbers[@]}"; do
        echo "$account_no"
        assume_role "$account_no" "$cdw_master_org_role"
        regions=$(aws ec2 describe-regions --query "Regions[].RegionName" --output text)

        for region in $regions; do
          echo "Scanning region: $region"

          # Lambda Functions
          lambda_list=($(aws lambda list-functions \
            --region "$region" \
            --query "Functions[].FunctionName" --output text | tr '\t' '\n' | grep -i "$SEARCH"))

          for name in "${lambda_list[@]}"; do
            append_csv "$region" "Lambda" "$name"
          done

          # CloudFormation Stacks
          stack_list=($(aws cloudformation list-stacks \
            --region "$region" \
            --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
            --query "StackSummaries[].StackName" --output text | tr '\t' '\n' | grep -i "$SEARCH"))

          for name in "${stack_list[@]}"; do
            append_csv "$region" "CloudFormationStack" "$name"
          done

          # Only run global services once
          if [ "$region" == "${regions%% *}" ]; then

            # StackSets
            stackset_list=($(aws cloudformation list-stack-sets --status ACTIVE \
              --query "Summaries[].StackSetName" --output text | tr '\t' '\n' | grep -i "$SEARCH"))
            for name in "${stackset_list[@]}"; do
              append_csv "GLOBAL" "StackSet" "$name"
            done

            # IAM Roles
            role_list=($(aws iam list-roles \
              --query "Roles[].RoleName" --output text | tr '\t' '\n' | grep -i "$SEARCH"))
            for name in "${role_list[@]}"; do
              append_csv "GLOBAL" "IAMRole" "$name"
            done

            # IAM Policies
            iam_policy_list=($(aws iam list-policies --scope Local \
              --query "Policies[].PolicyName" --output text | tr '\t' '\n' | grep -i "$SEARCH"))
            for name in "${iam_policy_list[@]}"; do
              append_csv "GLOBAL" "IAMPolicy" "$name"
            done

            # S3 Buckets
            s3_bucket_list=($(aws s3api list-buckets \
              --query "Buckets[].Name" --output text | tr '\t' '\n' | grep -i "$SEARCH"))
            for name in "${s3_bucket_list[@]}"; do
              append_csv "GLOBAL" "S3Bucket" "$name"
            done
          fi
        done
        assume_role "706839808421"

    done
    

  # Upload CSV to S3
  assume_role "706839808421"
  echo "Test"
  echo "Uploading CSV to S3: s3://$OUTPUT_BUCKET/$OUTPUT_KEY"
  aws s3 cp "$TEMP_CSV" "s3://$OUTPUT_BUCKET/$OUTPUT_KEY"

  echo "Upload complete!"
  
}


list
