variable "azure_environment" {
    description = "Which Azure Environment being used"
    type = string
    default = "public"
}

variable "tenant_id" {
    description = "Azure AD Tenant Id the resources are associated with"
    type = string
}