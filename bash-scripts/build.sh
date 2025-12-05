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


get_caller_identity() {
  caller_identity=$(aws sts get-caller-identity)

  verify_account=$(echo "$caller_identity" | jq -r '.Account')
  verify_role=$(echo "$caller_identity" | jq -r '.Arn' | awk -F '/' '{print $2}')
  
  echo "$verify_account $verify_role"
}



delete_stack() {
    echo "================================== Deleting Stacks ========================================="

    

    stack_list=($(aws cloudformation list-stacks \
            --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
            --query "StackSummaries[?ParentId==null].StackName" --output text | tr '\t' '\n' | grep -i "$SEARCH" \
            | grep -ivE "$ignore_stack"))
    printf "%s\n" "${stack_list[@]}"

    if [ $stack_list ]; then
        for stack in "${stack_list[@]}"; do
            echo "Deleting stack: $stack"
            aws cloudformation delete-stack --stack-name "$stack"
            echo "Waiting for stack $stack deletion to complete..."
            aws cloudformation wait stack-delete-complete --stack-name "$stack"

            echo "Stack $stack deleted successfully."
        done
    else
        echo "No Stack Available with Name $SEARCH"
    fi


    
}

delete_stackset() {
    echo "================================== Deleting Stackset ========================================="

    

    stackset_list=($(aws cloudformation list-stack-sets --status ACTIVE \
        --query "Summaries[].StackSetName" --output text | tr '\t' '\n' | grep -i "$SEARCH" \
        | grep -ivE "$ignore_stackset"))
    printf "%s\n" "${stackset_list[@]}"

    if [ $stackset_list ]; then
        for ss in "${stackset_list[@]}"; do
            echo "Deleting StackSet: $ss"
            # Get accounts
            accounts=$(aws cloudformation list-stack-instances \
                --stack-set-name "$ss" \
                --query 'Summaries[].Account' --output text 2>/dev/null)
            # Get regions
            regions=$(aws cloudformation list-stack-instances \
                --stack-set-name "$ss" \
                --query 'Summaries[].Region' --output text 2>/dev/null)
            # If no instances exist, skip to deletion
            if [[ -z "$accounts" || -z "$regions" ]]; then
                echo "No instances found for $ss, deleting StackSet directly..."
                aws cloudformation delete-stack-set --stack-set-name "$ss"
                continue
            fi
            echo "Deleting instances of $ss"
            # Delete instances
            opid=$(aws cloudformation delete-stack-instances \
                --stack-set-name "$ss" \
                --accounts $accounts \
                --regions $regions \
                --no-retain-stacks \
                --operation-preferences FailureToleranceCount=0,MaxConcurrentCount=1 \
                --query 'OperationId' --output text)
            echo "Waiting for operation: $opid"
            aws cloudformation wait stack-set-operation-succeeded \
                --stack-set-name "$ss" \
                --operation-id "$opid"
            echo "Deleting StackSet $ss"
            aws cloudformation delete-stack-set --stack-set-name "$ss"
        done
    else
        echo "No StackSet Available with Name $SEARCH"
    fi

    
}

delete_scp() {
    echo "================================ Deleting SCPs ======================================"

    

    # Get list of SCP names matching search
    scp_list=($(aws organizations list-policies --filter SERVICE_CONTROL_POLICY \
      --query "Policies[].Name" --output text \
      | tr '\t' '\n' \
      | grep -Ei "$SCP_SEARCH" \
      | grep -ivE "$ignore_scp"))

    echo "Found SCPs:"
    printf "%s\n" "${scp_list[@]}"

    if [ $scp_list ]; then
        for scp_name in "${scp_list[@]}"; do
            echo "Processing SCP: $scp_name"

            # Get SCP ID
            scp_id=$(aws organizations list-policies --filter SERVICE_CONTROL_POLICY \
                --query "Policies[?Name=='$scp_name'].Id" \
                --output text)

            if [[ -z "$scp_id" || "$scp_id" == "None" ]]; then
                echo "SCP '$scp_name' not found. Skipping."
                continue
            fi

            echo "Found SCP ID: $scp_id"

            echo "----- Checking and detaching attachments -----"

            # Get all targets the policy is attached to
            attached_targets=$(aws organizations list-targets-for-policy \
                --policy-id "$scp_id" \
                --query "Targets[].TargetId" \
                --output text)

            if [[ -z "$attached_targets" ]]; then
                echo "No attachments found for $scp_name"
            else
                echo "Attached targets: $attached_targets"
            fi

            # Detach only where attached
            for target in $attached_targets; do
                echo "Detaching $scp_name from $target"
                aws organizations detach-policy --policy-id "$scp_id" --target-id "$target"
                sleep 2
            done

            echo "----- Deleting SCP: $scp_name ($scp_id) -----"
            aws organizations delete-policy --policy-id "$scp_id"
            echo "Deleted: $scp_name"
            echo "----------------------------------------------------"
            sleep 3
        done
    else
        echo "No SCP Available with Name $SEARCH"
    fi
    
}

delete_lambda() {
    echo "====================================== Deleting Lambda ===================================="
    
    
    lambda_list=($(aws lambda list-functions --query "Functions[].FunctionName" --output text \
    | tr '\t' '\n' | grep -i "$SEARCH" \
    | grep -ivE "$ignore_lambda"))

    printf "%s\n" "${lambda_list[@]}"

    if [ $lambda_list ]; then
        for lambda in "${lambda_list[@]}"; do
            echo "Deleting Lambda: $lambda"
            aws lambda delete-function --function-name "$lambda"
        done
    else
        echo "No Lambda Available with Name $SEARCH"
    fi
    
}

delete_iam_role() {
    echo "======================================= Deleting IAM Role ======================================="

    

    role_list=($(aws iam list-roles \
        --query "Roles[].RoleName" \
        --output text | tr '\t' '\n' | grep -i "$SEARCH" | grep -iv "$cdw_offboarding_role" \
        | grep -ivE "$get_ignore_iam_role"))
    printf "%s\n" "${role_list[@]}"
    
    if [ $role_list ]; then
        for role in "${role_list[@]}"; do
            #1. Delete inline policies
            inline_policies=$(aws iam list-role-policies --role-name "$role" --query 'PolicyNames' --output text)
            for pol in $inline_policies; do
                echo "  - Deleting inline policy: $pol"
                aws iam delete-role-policy --role-name "$role" --policy-name "$pol"
            done

            # 2. Detach managed policies
            attached_policies=$(aws iam list-attached-role-policies --role-name "$role" --query 'AttachedPolicies[].PolicyArn' --output text)
            for arn in $attached_policies; do
                echo "  - Detaching managed policy: $arn"
                aws iam detach-role-policy --role-name "$role" --policy-arn "$arn"
            done

            # 3. Remove from instance profiles
            profiles=$(aws iam list-instance-profiles-for-role --role-name "$role" --query 'InstanceProfiles[].InstanceProfileName' --output text)
            for prof in $profiles; do
                echo "  - Removing from instance profile: $prof"
                aws iam remove-role-from-instance-profile --instance-profile-name "$prof" --role-name "$role"
            done

            # 4. Delete the role
            echo "  - Deleting role..."
            aws iam delete-role --role-name "$role"

            echo "Deleted: $role"
        done
    else
        echo "No Role Available with Name $SEARCH"
    fi

    


}

delete_iam_policy() {
    echo "===================================== Deleting IAM Policy ============================================"

    

    iam_policy_list=($(aws iam list-policies --scope Local \
      --query "Policies[].PolicyName" --output text | tr '\t' '\n' | grep -i "$SEARCH" \
      | grep -ivE "$ignore_iam_policy"))
    printf "%s\n" "${iam_policy_list[@]}"
    
    if [ $iam_policy_list ]; then
        for policy_name in "${iam_policy_list[@]}"; do
            echo "Processing: $policy_name"

            # Get Policy ARN from name
            policy_arn=$(aws iam list-policies --scope Local \
                --query "Policies[?PolicyName=='$policy_name'].Arn | [0]" \
                --output text)

            if [[ "$policy_arn" == "None" || -z "$policy_arn" ]]; then
                echo "ARN not found, skipping..."
                continue
            fi

            echo "  ARN: $policy_arn"

            # Delete all non-default versions
            versions=$(aws iam list-policy-versions \
                --policy-arn "$policy_arn" \
                --query 'Versions[?IsDefaultVersion==`false`].VersionId' \
                --output text)

            for ver in $versions; do
                echo "  - Deleting version: $ver"
                aws iam delete-policy-version --policy-arn "$policy_arn" --version-id "$ver"
            done

            # Delete policy
            echo "  - Deleting policy..."
            aws iam delete-policy --policy-arn "$policy_arn"

            echo "Deleted $policy_name"
        done
    else
        echo "No Policy Available with Name $SEARCH"
    fi
    
}

delete_s3_bucket() {
    echo "========================================= Deleting S3 Bucket =========================================="
    

    # Get buckets containing SEARCH
    s3_bucket_list=($(aws s3api list-buckets \
        --query "Buckets[].Name" \
        --output text | tr '\t' '\n' | grep -i "$SEARCH" \
        | grep -ivE "$ignore_s3"))

    echo "Buckets to delete:"
    printf "%s\n" "${s3_bucket_list[@]}"
    
    if [ $s3_bucket_list ]; then
        for bucket in "${s3_bucket_list[@]}"; do
            echo "---------------------------------------------"
            echo "Deleting bucket: $bucket"

            echo "Removing all objects (including versions)"
            aws s3 rm "s3://$bucket" --recursive >/dev/null 2>&1

            echo "Removing versioned objects (if any)"
            aws s3api delete-objects \
                --bucket "$bucket" \
                --delete "$(aws s3api list-object-versions --bucket "$bucket" \
                    --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}')" \
                >/dev/null 2>&1 || true

            echo "Removing delete markers (if any)"
            aws s3api delete-objects \
                --bucket "$bucket" \
                --delete "$(aws s3api list-object-versions --bucket "$bucket" \
                    --query='{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}')" \
                >/dev/null 2>&1 || true

            echo "Deleting bucket"
            aws s3api delete-bucket --bucket "$bucket" >/dev/null 2>&1 || true

            echo "Following Bucket deleted successfully: $bucket"
        done


        echo "---------------------------------------------"
        echo "All matching buckets deleted."
    else
        echo "No S3 Bucket Available with Name $SEARCH"
    fi

    
}

delete_cur_report() {
    echo "========================================= Deleting CUR Report =========================================="

    

    # Get report names that match search
    report_list=($(aws cur describe-report-definitions \
        --region $n_virginia_region \
        --query "ReportDefinitions[].ReportName" \
        --output text | tr '\t' '\n' | grep -i "$SEARCH" \
        | grep -ivE "$ignore_cur"))

    echo "Reports found:"
    printf "%s\n" "${report_list[@]}"
    if [ $report_list ]; then
        # Delete each matching report
        for report in "${report_list[@]}"; do
            echo "Deleting CUR report: $report"
            aws cur delete-report-definition \
                --region $n_virginia_region \
                --report-name "$report"
        done
        echo "Deleted all CUR Report with $SEARCH"
    else
        echo "No CUR Report Available with $SEARCH"
    fi

    
}

#start offboarding one by one
start_offboarding() {
    assume_role "$account_no" "$cdw_offboarding_role"
    read verify_account verify_role <<< "$(get_caller_identity)"

    if [ $account_no == $verify_account ]; then
        echo "Successfully Logged into Customer Account: $verify_account using $verify_role"
        
        delete_stack
        delete_stackset
        delete_scp
        delete_lambda
        delete_iam_role
        delete_iam_policy
        delete_s3_bucket
        delete_cur_report

        assume_role "$bluemoon"
        read verify_account verify_role <<< "$(get_caller_identity)"
        echo "Successfully Logged into Bluemoon Account: $verify_account using $verify_role"
    fi
}

start_offboarding
