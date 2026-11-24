# Example: how the platform team adds ONE use case in its own Terraform repo.
# This file is only an example: it is validated, never applied from this template.

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
  }
}

# Login and subscription come from the environment (ARM_* variables / az login),
# never from this file.
provider "azurerm" {
  features {}
}

module "ml_tool_wear" {
  source = "../.."

  department   = "manufacturing"
  name         = "tool-wear"
  owner        = "[owner]"                  # replace with the real owner
  github_repo  = "example-org/ml-tool-wear" # replace with the real repo
  gpu          = false
  data_domains = ["[data domain]"] # replace; access is granted in Fabric by hand

  # The department workspace, created once with the ml-workspace module.
  workspace_name                = "[department workspace]"
  workspace_resource_group_name = "[department resource group]"
  container_registry_id         = "[workspace container registry ID]" # ml-workspace output
}

output "github_variables" {
  description = "Values to set as GitHub repository variables."
  value = {
    AZURE_CLIENT_ID       = module.ml_tool_wear.azure_client_id
    AZURE_TENANT_ID       = module.ml_tool_wear.azure_tenant_id
    AZURE_SUBSCRIPTION_ID = module.ml_tool_wear.azure_subscription_id
    AZURE_ML_WORKSPACE    = module.ml_tool_wear.workspace_name
    AZURE_RESOURCE_GROUP  = module.ml_tool_wear.resource_group_name
  }
}

output "cluster" {
  description = "The project's cluster: its name goes into jobs/*.yml, its machine type into config.yml (cost)."
  value       = module.ml_tool_wear.cluster
}
