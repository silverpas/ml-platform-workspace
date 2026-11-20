# Which Terraform and provider versions this module works with.
# A module never configures the provider itself (subscription, login):
# the platform repo that calls the module does that.

terraform {
  required_version = ">= 1.7" # 1.7+ is needed for `terraform test` with mock providers

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.81"
    }
    azuread = {
      source  = "hashicorp/azuread" # Entra ID: only used when create_team_group = true
      version = "~> 3.10"
    }
  }
}
