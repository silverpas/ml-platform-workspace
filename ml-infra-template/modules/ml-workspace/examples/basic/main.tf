# Example: how the platform team adds ONE department workspace in its own
# Terraform repo. This file is only an example: it is validated, never applied
# from this template.

terraform {
  required_version = ">= 1.7"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.81"
    }
  }
}

# Login and subscription come from the environment (ARM_* variables / az login),
# never from this file.
provider "azurerm" {
  features {}
}

module "ml_workspace_manufacturing" {
  source = "../.."

  department          = "manufacturing"
  resource_group_name = "[existing resource group]" # replace
  owner               = "[platform team]"           # replace
  gpu                 = false
}

output "workspace" {
  description = "What the ml-project module and the project template need."
  value = {
    workspace_name      = module.ml_workspace_manufacturing.workspace_name
    resource_group_name = module.ml_workspace_manufacturing.resource_group_name
    cpu_cluster_name    = module.ml_workspace_manufacturing.cpu_cluster_name
  }
}
