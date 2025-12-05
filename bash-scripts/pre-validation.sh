#Getting requiring variables from get-variable generated file
if [ -f /tmp/build_vars.sh ]; then
    source /tmp/build_vars.sh
else 
    echo "Build variables not found! Did pre-build succeed?"
    exit 1
fi

if [[ -z "$account_no" || "$account_no" == "null" ]]; then
  echo "-------------- Variable AccountNo is missing a value ----------------"
  exit 1
elif [[ ${#account_no} -ne 12 ]]; then
  echo "Account number length: ${#account_no}"
  echo "Enter correct account number"
  exit 1
else
    if aws sts assume-role --role-arn "arn:aws:iam::$account_no:role/$cdw_master_org_role" --role-session-name codepipeline-session >/dev/null 2>&1; then
        echo "Client Account Number: $account_no is valid"
    fi
fi