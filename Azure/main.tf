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

# Foundation
resource "azurerm_resource_group"  "service_resource_group"{
    name = var.resource_group_name
    location = local.primary_region
}

# Identities
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

# Key Vault
resource "azurerm_key_vault" "keyvault" {
    name = "${var.service_name}-${var.environment}"
    resource_group_name = azurerm_resource_group.service_resource_group.name
    location = azurerm_resource_group.service_resource_group.location
    sku_name = "standard"
    tenant_id = var.tenant_id
}

# Storage
resource "azurerm_storage_account" "storage_account" {
    name = "${var.service_name}${var.environment}"
    resource_group_name = azurerm_resource_group.service_resource_group.name
    location = azurerm_resource_group.service_resource_group.location
    account_tier = "Standard"
    account_replication_type = "GRS"
}

# Logging
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

# CosmosDb
resource "azurerm_cosmosdb_account" "cosmosaccount" {
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

resource "azurerm_cosmosdb_sql_database" "cosmosdb" {
    name = "identityguard"
    resource_group_name = azurerm_cosmosdb_account.cosmosaccount.resource_group_name
    account_name = azurerm_cosmosdb_account.cosmosaccount.name
  
}

resource "azurerm_cosmosdb_sql_container" "cosmoscontainer_directories" {
    name = "Directories"
    resource_group_name = azurerm_cosmosdb_sql_database.cosmosdb.resource_group_name
    account_name = azurerm_cosmosdb_sql_database.cosmosdb.account_name
    database_name = azurerm_cosmosdb_sql_database.cosmosdb.name
    partition_key_path = "/Area"
}

# Azure Function
data "azuread_client_config" "current" {

}

resource "azuread_application" "application_api"{
    display_name = "${var.service_name}-api-${var.environment}"
    owners = [data.azuread_client_config.current.object_id]
    sign_in_audience = "AzureADMyOrg"
    web {
        redirect_uris = ["https://localhost/.auth/login/aad/callback/"]
    }
}

resource "azuread_service_principal" "application_sp_api" {
    application_id = azuread_application.application_api.id
    owners = [data.azuread_client_config.current.object_id]
    description = "${var.service_name}-api-${var.environment}"
}

resource "azurerm_app_service_plan" "function_serviceplan" {
    name = "${var.service_name}-${var.environment}"
    resource_group_name = azurerm_resource_group.service_resource_group.name
    location = azurerm_resource_group.service_resource_group.location
    kind = "FunctionApp"
    sku {
        tier = "Dynamic"
        size = "Y1"
    }
}

resource "azurerm_function_app" "function_api" {
    name = "${var.service_name}-api-${var.environment}"
    resource_group_name = azurerm_resource_group.service_resource_group.name
    location = azurerm_resource_group.service_resource_group.location
    app_service_plan_id = azurerm_app_service_plan.function_serviceplan.id
    storage_account_name = azurerm_storage_account.storage_account.name
    storage_account_access_key = azurerm_storage_account.storage_account.primary_access_key

    identity {
        type = "UserAssigned"
        identity_ids = [azurerm_user_assigned_identity.graph_api_managed_identity.id,azurerm_user_assigned_identity.keyvault_api_managed_identity.id]
    }

    auth_settings {
      enabled = true
      active_directory {
        client_id = azuread_application.application_api.application_id
      }
    }
}
