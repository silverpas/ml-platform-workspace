# Example: one use case, Azure side (ml-project) and GitHub side
# (ml-project-github) together. Validated, never applied from this template.

terraform {
  required_version = ">= 1.7"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.81"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.10"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.13"
    }
  }
}

# Logins come from the environment (az login / ARM_* variables, GITHUB_TOKEN),
# never from this file.
provider "azurerm" {
  features {}
}

provider "github" {
  owner = "example-org" # replace
}

module "tool_wear_github" {
  source = "../.."

  identity_id   = module.tool_wear.identity_id
  github_repo   = "example-org/ml-tool-wear"        # replace
  template_repo = "example-org/ml-project-template" # replace
  azure = {
    client_id       = module.tool_wear.azure_client_id
    tenant_id       = module.tool_wear.azure_tenant_id
    subscription_id = module.tool_wear.azure_subscription_id
    resource_group  = module.tool_wear.resource_group_name
    workspace       = module.tool_wear.workspace_name
  }
}

module "tool_wear" {
  source = "../../../ml-project"

  department                    = "manufacturing"
  name                          = "tool-wear"
  owner                         = "[owner]"
  github_repo                   = "example-org/ml-tool-wear"
  create_github_login           = false # ml-project-github creates the login rules
  workspace_name                = "[project workspace]"
  workspace_resource_group_name = "[project resource group]"
  container_registry_id         = "[workspace container registry ID]"
}

output "repo_url" {
  value = module.tool_wear_github.repo_url
}
