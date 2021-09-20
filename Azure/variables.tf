variable "use_msi_to_authenticate" {
  description = "Use a managed service identity to authenticate"
  type = bool
  default = false
}

variable "azure_environment" {
    description = "Which Azure Environment being used"
    type = string
    default = "public"
}

variable "tenant_id" {
    description = "Azure AD Tenant Id the resources are associated with"
    type = string
}

variable "subscription_id" {
   description = "Azure Subscription the resources managed in"
   type = string
}

variable "resource_group_name"{
    description = "Resource group to deploy resource into"
    type = string
}

variable "service_name" {
  description = "Name of the service"
  type = string
}

variable "environment"{
    description = "What type of environment (dev,tst,uat,prd)"
    type = string
}

