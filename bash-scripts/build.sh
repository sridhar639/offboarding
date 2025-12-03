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
    unset $AWS_ACCESS_KEY_ID $AWS_SECRET_ACCESS_KEY $AWS_SESSION_TOKEN
    echo "Switched to Bluemoon account"
  fi
}


delete_stack() {
    assume_role "$account_no" "$cdw_offboarding_role"

    stack_list=($(aws cloudformation list-stacks \
            --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
            --query "StackSummaries[].StackName" --output text | tr '\t' '\n' | grep -i "$SEARCH"))
    printf "%s\n" "${stack_list[@]}"

    echo "================================== Deleting Stacks ========================================="
    for stack in "${stack_list[@]}"; do
        echo "Deleting stack: $stack"
        aws cloudformation delete-stack --stack-name "$stack"
        echo "Waiting for stack $stack deletion to complete..."
        aws cloudformation wait stack-delete-complete --stack-name "$stack"

        echo "Stack $stack deleted successfully."
    done

    assume_role "bluemoon"
}

delete_stackset() {
    assume_role "$account_no" "$cdw_offboarding_role"

    stackset_list=($(aws cloudformation list-stack-sets --status ACTIVE \
        --query "Summaries[].StackSetName" --output text | tr '\t' '\n' | grep -i "$SEARCH"))
    printf "%s\n" "${stackset_list[@]}"

    echo "================================== Deleting Stackset ========================================="
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

    assume_role "bluemoon"
}

delete_scp() {
    assume_role "$account_no" "$cdw_offboarding_role"

    SCP_SEARCH="cdw|support"

    # Get list of SCP names matching search
    scp_list=($(aws organizations list-policies --filter SERVICE_CONTROL_POLICY \
      --query "Policies[].Name" --output text \
      | tr '\t' '\n' \
      | grep -Ei "$SCP_SEARCH"))

    echo "Found SCPs:"
    printf "%s\n" "${scp_list[@]}"

    echo "================= Deleting SCPs ==========================="

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


    assume_role "bluemoon"
}

delete_lambda() {
    assume_role "$account_no" "$cdw_offboarding_role"
    lambda_list=($(aws lambda list-functions --query "Functions[].FunctionName" --output text | tr '\t' '\n' | grep -i "$SEARCH"))
    printf "%s\n" "${lambda_list[@]}"

    for lambda in "${lambda_list[@]}"; do
        echo "Deleting Lambda: $lambda"
        aws lambda delete-function --function-name "$lambda"
    done
    assume_role "bluemoon"
}

delete_iam_role() {
    assume_role "$account_no" "$cdw_offboarding_role"

    role_list=($(aws iam list-roles \
        --query "Roles[].RoleName" \
        --output text | tr '\t' '\n' | grep -i "$SEARCH" | grep -iv "$cdw_offboarding_role"))
    printf "%s\n" "${role_list[@]}"

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

    assume_role "bluemoon"


}

delete_iam_policy() {
    assume_role "$account_no" "$cdw_offboarding_role"

    iam_policy_list=($(aws iam list-policies --scope Local \
      --query "Policies[].PolicyName" --output text | tr '\t' '\n' | grep -i "$SEARCH"))
    printf "%s\n" "${iam_policy_list[@]}"

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

    assume_role "bluemoon"
}

delete_s3_bucket() {
    assume_role "$account_no" "$cdw_offboarding_role"

    # Get buckets containing SEARCH
    s3_bucket_list=($(aws s3api list-buckets \
        --query "Buckets[].Name" \
         --output text | tr '\t' '\n' | grep -i "$SEARCH"))

    echo "Buckets to delete:"
    printf "%s\n" "${s3_bucket_list[@]}"

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

    assume_role "bluemoon"
}

#start offboarding one by one
delete_stack
delete_stackset
delete_scp
delete_lambda
delete_iam_role
delete_iam_policy
delete_s3_bucket