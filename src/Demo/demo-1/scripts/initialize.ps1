$resourceGroupName = "idguard-tf"
$storageAccountName = "idguardtfstate"
$containerName = "demo-1"
$fileName = "demo-1.terraform.tfstate"

terraform init -input=false `
    -backend-config="resource_group_name=${resourceGroupName}" `
    -backend-config="storage_account_name=${storageAccountName}" `
    -backend-config="container_name=${containerName}" `
    -backend-config="key=${fileName}"