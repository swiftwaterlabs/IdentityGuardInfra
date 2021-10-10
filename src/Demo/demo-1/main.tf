terraform {
  required_version = ">=1.0"

  required_providers {
    azurerm = {
      version = "=2.77.0"
      source  = "hashicorp/azurerm"
    }
    azuread = {
      version = "=2.6.0"
      source  = "hashicorp/azuread"
    }
  }
  backend "azurerm" {

  }
}

provider "azuread" {
  tenant_id       = var.tenant_id
  environment     = var.azure_environment
}

# Users
resource "random_uuid" "user_password" {}

resource "azuread_user" "westley" {
  user_principal_name = "westley@rolstadfamily.onmicrosoft.com"
  display_name        = "Dread Pirate Roberts"
  password            = random_uuid.user_password.result
  account_enabled = true
}

resource "azuread_user" "buttercup" {
  user_principal_name = "buttercup@rolstadfamily.onmicrosoft.com"
  display_name        = "Buttercup"
  password            = random_uuid.user_password.result
  account_enabled = true
}

resource "azuread_user" "humperdink" {
  user_principal_name = "humperdink@rolstadfamily.onmicrosoft.com"
  display_name        = "Prince Humperdink"
  password            = random_uuid.user_password.result
  account_enabled = true
}

resource "azuread_user" "vizzini" {
  user_principal_name = "vizzini@rolstadfamily.onmicrosoft.com"
  display_name        = "Vizzini"
  password            = random_uuid.user_password.result
  account_enabled = true
}

resource "azuread_user" "fezzik" {
  user_principal_name = "fezzik@rolstadfamily.onmicrosoft.com"
  display_name        = "Fezzik"
  password            = random_uuid.user_password.result
  account_enabled = true
}

resource "azuread_user" "inigo" {
  user_principal_name = "inigo@rolstadfamily.onmicrosoft.com"
  display_name        = "Inigo Montoya"
  password            = random_uuid.user_password.result
  account_enabled = true
}

resource "azuread_user" "cummerbund" {
  user_principal_name = "cummerbund@rolstadfamily.onmicrosoft.com"
  display_name        = "Cummerbund"
  password            = random_uuid.user_password.result
  account_enabled = true
}

resource "azuread_user" "roberts" {
  user_principal_name = "roberts@rolstadfamily.onmicrosoft.com"
  display_name        = "The Real Dread Pirate Roberts"
  password            = random_uuid.user_password.result
  account_enabled = true
}

# Groups
data "azuread_client_config" "current" {}

resource "azuread_group" "guilder" {
  display_name     = "Guilder"
  owners           = [azuread_user.humperdink.object_id, data.azuread_client_config.current.object_id]
  security_enabled = true
  members = [azuread_user.humperdink.object_id, azuread_user.buttercup.object_id]
}

resource "azuread_group" "florin" {
  display_name     = "Florin"
  owners           = [azuread_user.buttercup.object_id, data.azuread_client_config.current.object_id]
  security_enabled = true
  members = [azuread_user.westley.object_id, azuread_user.buttercup.object_id]
}

resource "azuread_group" "revenge_crew" {
  display_name     = "Revenge Crew"
  owners           = [azuread_user.westley.object_id, azuread_user.cummerbund.object_id, data.azuread_client_config.current.object_id]
  security_enabled = true
  members = [azuread_user.westley.object_id, azuread_user.cummerbund.object_id, azuread_user.roberts.object_id]
}

resource "azuread_group" "mercenary" {
  display_name     = "Mercenaries"
  owners           = [azuread_user.vizzini.object_id, data.azuread_client_config.current.object_id]
  security_enabled = true
  members = [azuread_user.vizzini.object_id, azuread_user.fezzik.object_id, azuread_user.inigo.object_id]
}

# Applications
resource "azuread_application" "revenge" {
  display_name     = "Pirate Ship Revenge"
  owners           = [azuread_user.westley.object_id, data.azuread_client_config.current.object_id]
  sign_in_audience = "AzureADMyOrg"
}

resource "azuread_service_principal" "revenge_sp" {
  application_id               = azuread_application.revenge.application_id
  owners                       = [azuread_user.westley.object_id, azuread_user.cummerbund.object_id, azuread_user.roberts.object_id, data.azuread_client_config.current.object_id]
  description                  = "The Revenge"
  app_role_assignment_required = false
}