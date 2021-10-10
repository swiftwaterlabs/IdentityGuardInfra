$tenantId = "335776b5-3fba-4122-bcef-84458b1b8201"

terraform apply -input=false `
    -auto-approve `
    -var="tenant_id=${tenant_id}" 