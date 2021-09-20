terraform {
    required_version = ">=1.0"

    required_providers {
        azurerm = {
            version = "=2.77.0"
            source = "hashicorp/azurerm"
        }
        azuread = {
            version = "=2.3.0"
            source = "hashicorp/azuread"
        }  
    }

    backend "azurerm"{

    }
}

provider "azurerm" {
  use_msi = var.use_msi_to_authenticate
  subscription_id = var.subscription_id
  tenant_id = var.tenant_id
  environment = var.environment
   features {
                key_vault {
                    purge_soft_delete_on_destroy = true
                }
            }
}

locals {
    primary_region = var.regions[0]
}

resource "azurerm_resource_group"  "service_resource_group"{
    name = var.resource_group_name
    location = local.primary_region
}

resource "azurerm_user_assigned_identity" "graph_api_managed_identity" {
    name = "${var.service_name}-graphapi-${var.environment}"
    resource_group_name = azurerm_resource_group.service_resource_group.name
    location = azurerm_resource_group.service_resource_group.location
}

resource "azurerm_user_assigned_identity" "keyvault_api_managed_identity" {
    name = "${var.service_name}-keyvault-${var.environment}"
    resource_group_name = azurerm_resource_group.service_resource_group.name
    location = azurerm_resource_group.service_resource_group.location
}

resource "azurerm_key_vault" "keyvault" {
    name = "${var.service_name}-${var.environment}"
    resource_group_name = azurerm_resource_group.service_resource_group.name
    location = azurerm_resource_group.service_resource_group.location
    sku_name = "standard"
    tenant_id = var.tenant_id
}

resource "azurerm_storage_account" "storage_account" {
    name = "${var.service_name}${var.environment}"
    resource_group_name = azurerm_resource_group.service_resource_group.name
    location = azurerm_resource_group.service_resource_group.location
    account_tier = "Standard"
    account_replication_type = "GRS"
}

resource "azurerm_log_analytics_workspace" "loganalytics" {
    name = "${var.service_name}-${var.environment}"
    resource_group_name = azurerm_resource_group.service_resource_group.name
    location = azurerm_resource_group.service_resource_group.location
    sku = "PerGB2018"
}

resource "azurerm_application_insights" "appinsights" {
    name = "${var.service_name}-${var.environment}"
    resource_group_name = azurerm_resource_group.service_resource_group.name
    location = azurerm_resource_group.service_resource_group.location
    workspace_id = azurerm_log_analytics_workspace.loganalytics.id
    application_type = "web"
}

resource "azurerm_cosmosdb_account" "cosmosdb" {
    name = "${var.service_name}-${var.environment}"
    resource_group_name = azurerm_resource_group.service_resource_group.name
    location = azurerm_resource_group.service_resource_group.location
    offer_type = "Standard"
    kind = "GlobalDocumentDB"

    geo_location {
      location = azurerm_resource_group.service_resource_group.location
      failover_priority = 0
    }

    consistency_policy {
      consistency_level = "Session"
    }

    capabilities {
      name = "EnableServerless"
    }

}