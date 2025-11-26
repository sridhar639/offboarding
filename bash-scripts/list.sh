#!/bin/bash

SEARCH="cdw"

echo "=== Lambda Functions ==="
aws lambda list-functions --query "Functions[].FunctionName" --output text | tr '\t' '\n' | grep -i "$SEARCH"

echo "=== CloudFormation Stacks ==="
aws cloudformation list-stacks \
  --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
  --query "StackSummaries[].StackName" --output text | tr '\t' '\n' | grep -i "$SEARCH"

echo "=== CloudFormation StackSets ==="
aws cloudformation list-stack-sets --status ACTIVE \
  --query "Summaries[].StackSetName" --output text | tr '\t' '\n' | grep -i "$SEARCH"

echo "=== IAM Roles ==="
aws iam list-roles --query "Roles[].RoleName" --output text | tr '\t' '\n' | grep -i "$SEARCH"

echo "=== IAM Policies ==="
aws iam list-policies --scope Local \
  --query "Policies[].PolicyName" --output text | tr '\t' '\n' | grep -i "$SEARCH"

echo "=== S3 Buckets ==="
aws s3api list-buckets --query "Buckets[].Name" --output text | tr '\t' '\n' | grep -i "$SEARCH"
