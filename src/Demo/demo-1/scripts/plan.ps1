$tenantId = "335776b5-3fba-4122-bcef-84458b1b8201"

terraform plan -input=false `
    -var="tenant_id=${tenant_id}"  `
    -out "demo-1.tfplan"