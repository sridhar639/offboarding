offboarding_variable_file="cloudformation/offboarding_variables.yaml"
ignore_list_file="cloudformation/ignore_list.yaml"

account_no=$(yq -r '.AccountNo.Value' "$offboarding_variable_file")

ignore_list=$(yq -r '.Ignore.Value' "$ignore_list_file")

cdw_master_org_role="CDWMasterOrgAdminRole"

cdw_offboarding_role="CDWOffboardingRole"

bluemoon_account="706839808421"

SEARCH="cdw"

bluemoon="bluemoon"




#Exporting all the values
cat <<EOL >> /tmp/build_vars.sh
export account_no="$account_no"
export cdw_master_org_role="$cdw_master_org_role"
export cdw_offboarding_role="$cdw_offboarding_role"
export bluemoon_account="$bluemoon_account"
export SEARCH="$SEARCH"
export ignore_list="$ignore_list"
EOL

echo -e "\nWrote Everything to /tmp/build_vars.sh"
echo "================ File Contents ================"
cat /tmp/build_vars.sh
echo "==============================================="