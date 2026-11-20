# Tests for the ml-project module. Run with:
#   terraform -chdir=infra/modules/ml-project init -backend=false
#   terraform -chdir=infra/modules/ml-project test
#
# `mock_provider` replaces Azure with a fake: no login, no cost, nothing is created.
# Each `run` makes a plan and checks what WOULD be created.

mock_provider "azurerm" {
  # The fake "existing" department workspace the module looks up.
  mock_data "azurerm_machine_learning_workspace" {
    defaults = {
      id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ml-manufacturing/providers/Microsoft.MachineLearningServices/workspaces/mlw-manufacturing"
      location = "swedencentral"
    }
  }
}

# Shared inputs; single runs override what they test.
variables {
  department                    = "manufacturing"
  name                          = "machine-fail"
  owner                         = "maintenance-analytics-team"
  github_repo                   = "example-org/ml-machine-failure"
  workspace_name                = "mlw-manufacturing"
  workspace_resource_group_name = "rg-ml-manufacturing"
}

run "cpu_by_default" {
  command = plan

  assert {
    condition     = azurerm_machine_learning_compute_cluster.project.vm_size == "Standard_DS3_v2"
    error_message = "Without gpu = true the cluster should use the CPU machine type."
  }

  assert {
    condition     = azurerm_machine_learning_compute_cluster.project.scale_settings[0].min_node_count == 0
    error_message = "The cluster must scale to 0 machines so it costs nothing when idle."
  }

  assert {
    condition     = azurerm_machine_learning_compute_cluster.project.name == "cc-machine-fail"
    error_message = "Unexpected compute cluster name."
  }
}

run "gpu_on_request" {
  command = plan

  variables {
    gpu = true
  }

  assert {
    condition     = azurerm_machine_learning_compute_cluster.project.vm_size == "Standard_NC4as_T4_v3"
    error_message = "With gpu = true the cluster should use the GPU machine type."
  }
}

run "github_can_only_log_in_from_this_repo" {
  command = plan

  assert {
    condition     = azurerm_federated_identity_credential.github_main.subject == "repo:example-org/ml-machine-failure:ref:refs/heads/main"
    error_message = "Training login must be limited to the main branch of this repo."
  }

  assert {
    condition     = azurerm_federated_identity_credential.github_deploy.subject == "repo:example-org/ml-machine-failure:environment:production"
    error_message = "Deploy login must be limited to the approval-gated environment of this repo."
  }
}

run "least_privilege_role_on_the_workspace" {
  command = plan

  assert {
    condition     = azurerm_role_assignment.workspace.role_definition_name == "AzureML Data Scientist"
    error_message = "The project identity should get the AzureML Data Scientist role, nothing broader."
  }

  assert {
    condition     = endswith(azurerm_role_assignment.workspace.scope, "/workspaces/mlw-manufacturing")
    error_message = "The role must be limited to the department workspace."
  }
}

run "tags_show_owner_and_department" {
  command = plan

  assert {
    condition     = azurerm_user_assigned_identity.project.tags["owner"] == "maintenance-analytics-team"
    error_message = "Every resource should be tagged with its owner."
  }

  assert {
    condition     = azurerm_user_assigned_identity.project.tags["department"] == "manufacturing"
    error_message = "Every resource should be tagged with its department."
  }
}

run "rejects_bad_name" {
  command = plan

  variables {
    name = "Name_Too_Long_And_Uppercase"
  }

  expect_failures = [var.name]
}

run "rejects_bad_github_repo" {
  command = plan

  variables {
    github_repo = "not-a-repo"
  }

  expect_failures = [var.github_repo]
}
