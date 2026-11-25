# Tests for the ml-project-github module. Run with:
#   terraform -chdir=modules/ml-project-github init -backend=false
#   terraform -chdir=modules/ml-project-github test
#
# `mock_provider` replaces GitHub with a fake: no login, nothing is created.

mock_provider "azurerm" {}

mock_provider "github" {
  mock_data "github_rest_api" {
    defaults = {
      body = "{\"id\": 123}"
    }
  }

  mock_data "github_repository" {
    defaults = {
      repo_id = 456
    }
  }
}

variables {
  identity_id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ml-manufacturing/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-ml-manufacturing-tool-wear"
  github_repo   = "example-org/ml-tool-wear"
  template_repo = "example-org/ml-project-template"
  azure = {
    client_id       = "00000000-0000-0000-0000-000000000001"
    tenant_id       = "00000000-0000-0000-0000-000000000002"
    subscription_id = "00000000-0000-0000-0000-000000000003"
    resource_group  = "rg-ml-manufacturing"
    workspace       = "mlw-manufacturing"
  }
}

run "creates_a_private_repo_from_the_template" {
  command = plan

  assert {
    condition     = github_repository.project[0].name == "ml-tool-wear" && github_repository.project[0].visibility == "private"
    error_message = "The project repo should be created, private by default."
  }

  assert {
    condition     = github_repository.project[0].template[0].repository == "ml-project-template"
    error_message = "The repo must be created from the project template."
  }

  assert {
    condition     = github_repository.project[0].archive_on_destroy
    error_message = "Destroying must archive the repo, never delete it."
  }
}

run "sets_the_five_azure_variables" {
  command = plan

  assert {
    condition     = length(github_actions_variable.azure) == 5
    error_message = "The workflows need exactly five variables."
  }

  assert {
    condition     = github_actions_variable.azure["AZURE_ML_WORKSPACE"].value == "mlw-manufacturing" && github_actions_variable.azure["AZURE_CLIENT_ID"].value == "00000000-0000-0000-0000-000000000001"
    error_message = "Variable values must come from the azure input."
  }
}

run "environment_without_reviewers_by_default" {
  command = plan

  assert {
    condition     = github_repository_environment.deploy.environment == "production" && length(github_repository_environment.deploy.reviewers) == 0
    error_message = "The production environment should exist, without reviewers unless given."
  }

  assert {
    condition     = !output.has_approval_gate
    error_message = "Without reviewers there is no approval gate."
  }
}

run "reviewers_on_request" {
  command = plan

  variables {
    reviewer_user_ids = [111]
  }

  assert {
    condition     = github_repository_environment.deploy.reviewers[0].users == toset([111]) && output.has_approval_gate
    error_message = "Reviewers given in reviewer_user_ids must be required."
  }
}

run "existing_repo_is_adopted_and_ids_are_read" {
  command = plan

  variables {
    create_repo = false
  }

  assert {
    condition     = length(github_repository.project) == 0
    error_message = "With create_repo = false no repo may be created."
  }

  assert {
    condition     = output.github_ids.owner_id == 123 && output.github_ids.repo_id == 456
    error_message = "The numeric IDs must be read from GitHub for ml-project."
  }
}

run "rejects_public_repos" {
  command = plan

  variables {
    visibility = "public"
  }

  expect_failures = [var.visibility]
}

run "needs_a_template_to_create_a_repo" {
  command = plan

  variables {
    template_repo = null
  }

  expect_failures = [github_repository.project]
}

run "login_rules_use_the_numeric_ids" {
  command = plan

  variables {
    create_repo = false
  }

  assert {
    condition     = azurerm_federated_identity_credential.github_main.subject == "repo:example-org@123/ml-tool-wear@456:ref:refs/heads/main"
    error_message = "The main-branch login rule must match GitHub's subject, with IDs."
  }

  assert {
    condition     = azurerm_federated_identity_credential.github_deploy.subject == "repo:example-org@123/ml-tool-wear@456:environment:production"
    error_message = "The deploy login rule must match GitHub's subject, with IDs."
  }
}
