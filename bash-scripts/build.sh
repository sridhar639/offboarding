#Getting requiring variables from get-variable generated file
if [ -f /tmp/build_vars.sh ]; then
    source /tmp/build_vars.sh
else 
    echo "Build variables not found! Did pre-build succeed?"
    exit 1
fi

delete_cdw_resources() {

echo "Deleting Stacks"
for stack in "${stack_list[@]}"; do
    echo "Deleting stack: $stack"
    aws cloudformation delete-stack --stack-name "$stack"
done


}

delete_cdw_resources