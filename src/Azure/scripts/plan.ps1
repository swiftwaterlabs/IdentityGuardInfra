$fileName = "dev.terraform.tfstate"
$serviceName = "idguard"
$environment = "dev"

terraform plan -input=false `
    -var="service_name=${serviceName}" `
    -var-file=".\config\${serviceName}.tfvars" `
    -var-file=".\config\${environment}.tfvars" `
    -out "${fileName}.tfplan"