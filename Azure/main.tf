terraform {
  required_version = ">=1.0"

  required_providers {
    azurerm = {
      version = "=2.77.0"
      source  = "hashicorp/azurerm"
    }
    azuread = {
      version = "=2.3.0"
      source  = "hashicorp/azuread"
    }
  }
  backend "azurerm" {

  }
}

provider "azurerm" {
  use_msi         = var.use_msi_to_authenticate
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  environment     = var.azure_environment
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

data "azuread_client_config" "current" {

}

locals {
  primary_region                = var.regions[0]
  functions_baseurl             = var.azure_environment == "usgovernment" ? "azurewebsites.us" : "azurewebsites.net"
  api_base_url                  = "${var.service_name}-api-${var.environment}.${local.functions_baseurl}"
  executing_serviceprincipal_id = data.azuread_client_config.current.object_id
  application_owners            = [local.executing_serviceprincipal_id]
}

# Foundation
resource "azurerm_resource_group" "service_resource_group" {
  name     = var.resource_group_name
  location = local.primary_region
}

# Identities
resource "azurerm_user_assigned_identity" "graph_api_managed_identity" {
  name                = "${var.service_name}-graphapi-${var.environment}"
  resource_group_name = azurerm_resource_group.service_resource_group.name
  location            = azurerm_resource_group.service_resource_group.location
}

resource "azurerm_user_assigned_identity" "keyvault_api_managed_identity" {
  name                = "${var.service_name}-keyvault-${var.environment}"
  resource_group_name = azurerm_resource_group.service_resource_group.name
  location            = azurerm_resource_group.service_resource_group.location
}

# Key Vault
resource "azurerm_key_vault" "keyvault" {
  name                = "${var.service_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.service_resource_group.name
  location            = azurerm_resource_group.service_resource_group.location
  sku_name            = "standard"
  tenant_id           = var.tenant_id
}

resource "azurerm_key_vault_access_policy" "executing_owner_access" {
  key_vault_id = azurerm_key_vault.keyvault.id
  tenant_id    = azurerm_key_vault.keyvault.tenant_id
  object_id    = local.executing_serviceprincipal_id

  secret_permissions = ["Get", "Set", "List", "Delete"]
}

resource "azurerm_key_vault_access_policy" "api_access" {
  key_vault_id = azurerm_key_vault.keyvault.id
  tenant_id    = azurerm_key_vault.keyvault.tenant_id
  object_id    = azurerm_user_assigned_identity.keyvault_api_managed_identity.principal_id

  secret_permissions = ["Get"]
}

# Storage
resource "azurerm_storage_account" "storage_account" {
  name                     = "${var.service_name}${var.environment}"
  resource_group_name      = azurerm_resource_group.service_resource_group.name
  location                 = azurerm_resource_group.service_resource_group.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
}

# Logging
resource "azurerm_log_analytics_workspace" "loganalytics" {
  name                = "${var.service_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.service_resource_group.name
  location            = azurerm_resource_group.service_resource_group.location
  sku                 = "PerGB2018"
}

resource "azurerm_application_insights" "appinsights" {
  name                = "${var.service_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.service_resource_group.name
  location            = azurerm_resource_group.service_resource_group.location
  workspace_id        = azurerm_log_analytics_workspace.loganalytics.id
  application_type    = "web"
}

# CosmosDb
resource "azurerm_cosmosdb_account" "cosmosaccount" {
  name                = "${var.service_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.service_resource_group.name
  location            = azurerm_resource_group.service_resource_group.location
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  geo_location {
    location          = azurerm_resource_group.service_resource_group.location
    failover_priority = 0
  }

  consistency_policy {
    consistency_level = "Session"
  }

  capabilities {
    name = "EnableServerless"
  }

}

resource "azurerm_key_vault_secret" "cosmos_primary_key" {
  key_vault_id = azurerm_key_vault.keyvault.id
  name         = "cosmos-primary-key"
  value        = azurerm_cosmosdb_account.cosmosaccount.primary_key
}

resource "azurerm_cosmosdb_sql_database" "cosmosdb" {
  name                = "identityguard"
  resource_group_name = azurerm_cosmosdb_account.cosmosaccount.resource_group_name
  account_name        = azurerm_cosmosdb_account.cosmosaccount.name

}

resource "azurerm_cosmosdb_sql_container" "cosmoscontainer_directories" {
  name                = "Directories"
  resource_group_name = azurerm_cosmosdb_sql_database.cosmosdb.resource_group_name
  account_name        = azurerm_cosmosdb_sql_database.cosmosdb.account_name
  database_name       = azurerm_cosmosdb_sql_database.cosmosdb.name
  partition_key_path  = "/Area"
}

# Azure Function
resource "azuread_application" "application_api" {
  display_name     = "${var.service_name}-api-${var.environment}"
  owners           = local.application_owners
  sign_in_audience = "AzureADMyOrg"
  web {
    redirect_uris = ["https://${local.api_base_url}/.auth/login/aad/callback/"]

    implicit_grant {
      access_token_issuance_enabled = true
      id_token_issuance_enabled     = true
    }
  }

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph
    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d" # User.Read
      type = "Scope"
    }
  }
}

resource "azuread_service_principal" "application_sp_api" {
  application_id               = azuread_application.application_api.application_id
  owners                       = local.application_owners
  description                  = "${var.service_name}-api-${var.environment}"
  app_role_assignment_required = false
}

resource "azurerm_app_service_plan" "function_serviceplan" {
  name                = "${var.service_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.service_resource_group.name
  location            = azurerm_resource_group.service_resource_group.location
  kind                = "FunctionApp"
  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

resource "azurerm_function_app" "function_api" {
  name                       = "${var.service_name}-api-${var.environment}"
  resource_group_name        = azurerm_resource_group.service_resource_group.name
  location                   = azurerm_resource_group.service_resource_group.location
  app_service_plan_id        = azurerm_app_service_plan.function_serviceplan.id
  storage_account_name       = azurerm_storage_account.storage_account.name
  storage_account_access_key = azurerm_storage_account.storage_account.primary_access_key

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.graph_api_managed_identity.id, azurerm_user_assigned_identity.keyvault_api_managed_identity.id]
  }

  auth_settings {
    enabled = true
    active_directory {
      client_id = azuread_application.application_api.application_id
    }
  }
}

# Web UI
resource "azuread_application" "application_ui" {
  display_name     = "${var.service_name}-ui-${var.environment}"
  owners           = local.application_owners
  sign_in_audience = "AzureADMyOrg"
  single_page_application {
    redirect_uris = ["${var.ui_base_url}/authentication/login-callback"]
  }

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph
    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d" # User.Read
      type = "Scope"
    }
  }
}

resource "azuread_service_principal" "application_sp_ui" {
  application_id               = azuread_application.application_ui.application_id
  owners                       = local.application_owners
  description                  = "${var.service_name}-ui-${var.environment}"
  app_role_assignment_required = false
}
