$serviceName = "idguard"
$environment = "dev"

terraform apply -input=false `
    -auto-approve `
    -destroy `
    -var="service_name=${serviceName}" `
    -var-file=".\config\${serviceName}.tfvars" `
    -var-file=".\config\${environment}.tfvars"