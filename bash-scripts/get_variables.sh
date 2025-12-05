offboarding_variable_file="cloudformation/offboarding_variables.yaml"
ignore_list_file="cloudformation/ignore_list.yaml"

account_no=$(yq -r '.AccountNo.Value' "$offboarding_variable_file")

ignore_list=$(yq -r '.Ignore.Value' "$ignore_list_file")

get_ignore_stack=$(echo "$ignore_list" | tr '|' '\n' | grep '^stack=' | cut -d'=' -f2)
ignore_stack="^($(echo "$ignore_stack" | paste -sd '|' -))$"

get_ignore_stackset=$(echo "$ignore_list" | tr '|' '\n' | grep '^stackset=' | cut -d'=' -f2)
ignore_stackset="^($(echo "$get_ignore_stackset" | paste -sd '|' -))$"

get_ignore_lambda=$(echo "$ignore_list" | tr '|' '\n' | grep '^lambda=' | cut -d'=' -f2)
ignore_lambda="^($(echo "$get_ignore_lambda" | paste -sd '|' -))$"

get_ignore_s3=$(echo "$ignore_list" | tr '|' '\n' | grep '^s3=' | cut -d'=' -f2)
ignore_s3="^($(echo "$get_ignore_s3" | paste -sd '|' -))$"

get_ignore_iam_policy=$(echo "$ignore_list" | tr '|' '\n' | grep '^iam_policy=' | cut -d'=' -f2)
ignore_iam_policy="^($(echo "$get_ignore_iam_policy" | paste -sd '|' -))$"

get_ignore_iam_role=$(echo "$ignore_list" | tr '|' '\n' | grep '^iam_role=' | cut -d'=' -f2)
ignore_iam_role="^($(echo "$get_ignore_iam_role" | paste -sd '|' -))$"

get_ignore_scp=$(echo "$ignore_list" | tr '|' '\n' | grep '^scp=' | cut -d'=' -f2)
ignore_scp="^($(echo "$get_ignore_scp" | paste -sd '|' -))$"

get_ignore_cur=$(echo "$ignore_list" | tr '|' '\n' | grep '^cur=' | cut -d'=' -f2)
ignore_cur="^($(echo "$get_ignore_cur" | paste -sd '|' -))$"



cdw_master_org_role="CDWMasterOrgAdminRole"

cdw_offboarding_role="CDWOffboardingRole"

bluemoon_account="706839808421"

SEARCH="cdw"

SCP_SEARCH="cdw|support"

bluemoon="bluemoon"

n_virginia_region="us-east-1"




#Exporting all the values
cat <<EOL >> /tmp/build_vars.sh
export account_no="$account_no"
export cdw_master_org_role="$cdw_master_org_role"
export cdw_offboarding_role="$cdw_offboarding_role"
export bluemoon_account="$bluemoon_account"
export SEARCH="$SEARCH"
export SCP_SEARCH="$SCP_SEARCH"
export ignore_list="$ignore_list"
export bluemoon="$bluemoon"
export n_virginia_region="$n_virginia_region"
export ignore_stack="$ignore_stack"
export ignore_stackset="$ignore_stackset"
export ignore_lambda="$ignore_lambda"
export ignore_s3="$ignore_s3"
export ignore_iam_policy="$ignore_iam_policy"
export ignore_iam_role="$ignore_iam_role"
export ignore_scp="$ignore_scp"
export ignore_cur="$ignore_cur"
EOL

