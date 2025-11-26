#!/bin/bash

SEARCH="cdw"

echo "=== Lambda Functions ==="
aws lambda list-functions --query "Functions[?contains(tolower(FunctionName), \`$SEARCH\`)].FunctionName" --output text

echo "=== CloudFormation Stacks ==="
aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE --query "StackSummaries[?contains(tolower(StackName), \`$SEARCH\`)].StackName" --output text

echo "=== CloudFormation StackSets ==="
aws cloudformation list-stack-sets --status ACTIVE --query "Summaries[?contains(tolower(StackSetName), \`$SEARCH\`)].StackSetName" --output text

echo "=== IAM Roles ==="
aws iam list-roles --query "Roles[?contains(tolower(RoleName), \`$SEARCH\`)].RoleName" --output text

echo "=== IAM Policies ==="
aws iam list-policies --scope Local --query "Policies[?contains(tolower(PolicyName), \`$SEARCH\`)].PolicyName" --output text

echo "=== S3 Buckets ==="
aws s3api list-buckets --query "Buckets[?contains(tolower(Name), \`$SEARCH\`)].Name" --output text
