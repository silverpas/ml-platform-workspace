# Terraform and provider versions, pinned. Same versions as the modules in
# ml-infra-template, so the modules and this root always agree.

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

  # ASSUMPTION: the real platform repo keeps state in a storage account with
  # OIDC login (backend "azurerm" with use_oidc = true), configured at
  # `terraform init` by its provisioning workflow. This example has no backend.
}

# Login and subscription come from the environment (ARM_* variables set by the
# workflow via OIDC, or `az login` locally), never from this file.
provider "azurerm" {
  features {}
}

provider "azuread" {}

# GitHub login comes from the environment (GITHUB_TOKEN, or a GitHub App in
# the platform's workflow), never from this file.
provider "github" {
  owner = var.github_owner
}
