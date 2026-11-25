# Which Terraform and provider versions this module works with.
# A module never configures the provider itself (owner, login): the platform
# repo that calls the module does that.

terraform {
  required_version = ">= 1.7" # 1.7+ is needed for `terraform test` with mock providers

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.13"
    }
    azurerm = {
      source  = "hashicorp/azurerm" # the GitHub login rules live on the Azure identity
      version = "~> 4.81"
    }
  }
}
