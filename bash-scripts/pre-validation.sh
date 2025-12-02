if [[ -z "$account_no" || "$account_no" == "null" ]]; then
  echo "-------------- Variable AccountNo is missing a value ----------------"
  exit 1
elif [[ ${#account_no} -ne 12 ]]; then
  echo "Account number length: ${#account_no}"
  echo "Enter correct account number"
  exit 1
else
    echo "Client Account Number: $account_no is valid"
fi