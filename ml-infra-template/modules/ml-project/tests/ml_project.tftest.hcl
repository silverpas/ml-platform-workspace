# Tests for the ml-project module. Run with:
#   terraform -chdir=modules/ml-project init -backend=false
#   terraform -chdir=modules/ml-project test
#
# `mock_provider` replaces Azure and Entra ID with fakes: no login, no cost,
# nothing is created. Each `run` makes a plan and checks what WOULD be created.

mock_provider "azurerm" {
  # The fake "existing" department workspace the module looks up.
  mock_data "azurerm_machine_learning_workspace" {
    defaults = {
      id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ml-manufacturing/providers/Microsoft.MachineLearningServices/workspaces/mlw-manufacturing"
      location = "swedencentral"
    }
  }
}

mock_provider "azuread" {}

# Shared inputs; single runs override what they test.
variables {
  department                    = "manufacturing"
  name                          = "tool-wear"
  owner                         = "maintenance-analytics-team"
  github_repo                   = "example-org/ml-tool-wear"
  workspace_name                = "mlw-manufacturing"
  workspace_resource_group_name = "rg-ml-manufacturing"
  container_registry_id         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ml-manufacturing/providers/Microsoft.ContainerRegistry/registries/crmlmanufactur123456"
}

run "own_cpu_cluster_scales_to_zero" {
  command = plan

  assert {
    condition     = azurerm_machine_learning_compute_cluster.project.name == "cpu-tool-wear" && output.compute_name == "cpu-tool-wear"
    error_message = "The project's cluster should be called cpu-<name> by default."
  }

  assert {
    condition     = azurerm_machine_learning_compute_cluster.project.vm_size == "Standard_DS3_v2"
    error_message = "Default CPU machine type should be Standard_DS3_v2."
  }

  assert {
    condition = alltrue([
      azurerm_machine_learning_compute_cluster.project.scale_settings[0].min_node_count == 0,
      azurerm_machine_learning_compute_cluster.project.scale_settings[0].max_node_count == 1,
      azurerm_machine_learning_compute_cluster.project.scale_settings[0].scale_down_nodes_after_idle_duration == "PT15M",
    ])
    error_message = "The cluster must scale to 0, at most 1 machine by default, idle machines off after 15 minutes."
  }
}

run "cluster_runs_as_the_project_identity_with_its_tags" {
  command = plan

  assert {
    condition     = azurerm_machine_learning_compute_cluster.project.identity[0].type == "UserAssigned"
    error_message = "The cluster must run as the project's own identity (data access per project)."
  }

  assert {
    condition     = azurerm_machine_learning_compute_cluster.project.tags["use_case"] == "tool-wear"
    error_message = "The cluster must carry the use_case tag (costs per project)."
  }

  assert {
    condition     = azurerm_role_assignment.registry[0].role_definition_name == "AcrPull"
    error_message = "The identity needs AcrPull on the registry to load the job environments."
  }
}

run "gpu_on_request" {
  command = plan

  variables {
    gpu = true
  }

  assert {
    condition     = azurerm_machine_learning_compute_cluster.project.name == "gpu-tool-wear" && azurerm_machine_learning_compute_cluster.project.vm_size == "Standard_NC4as_T4_v3"
    error_message = "With gpu = true the project should get its own GPU cluster."
  }
}

run "long_cluster_names_are_shortened" {
  command = plan

  variables {
    name        = "spindle-vibration-alerts"
    environment = "prod"
  }

  assert {
    condition     = length(azurerm_machine_learning_compute_cluster.project.name) <= 16 && startswith(azurerm_machine_learning_compute_cluster.project.name, "cpu-spind-")
    error_message = "Cluster names must fit Azure ML's 16-character limit."
  }
}

run "sandbox_without_role_assignments" {
  command = plan

  variables {
    create_role_assignments = false
    container_registry_id   = null
  }

  assert {
    condition     = length(azurerm_role_assignment.workspace) == 0 && length(azurerm_role_assignment.registry) == 0
    error_message = "With create_role_assignments = false no roles may be assigned."
  }

  assert {
    condition     = length(output.roles_to_assign_by_hand) == 2
    error_message = "The roles to assign by hand should be listed."
  }
}

run "github_can_only_log_in_from_this_repo" {
  command = plan

  assert {
    condition     = azurerm_federated_identity_credential.github_main[0].subject == "repo:example-org/ml-tool-wear:ref:refs/heads/main"
    error_message = "Training login must be limited to the main branch of this repo."
  }

  assert {
    condition     = azurerm_federated_identity_credential.github_deploy[0].subject == "repo:example-org/ml-tool-wear:environment:production"
    error_message = "Deploy login must be limited to the approval-gated environment of this repo."
  }
}

run "github_subject_with_numeric_ids" {
  command = plan

  variables {
    github_ids = {
      owner_id = 123
      repo_id  = 456
    }
  }

  assert {
    condition     = azurerm_federated_identity_credential.github_main[0].subject == "repo:example-org@123/ml-tool-wear@456:ref:refs/heads/main"
    error_message = "With github_ids the subject must contain the numeric IDs, as GitHub sends them."
  }

  assert {
    condition     = azurerm_federated_identity_credential.github_deploy[0].subject == "repo:example-org@123/ml-tool-wear@456:environment:production"
    error_message = "The deploy subject must also contain the numeric IDs."
  }
}

run "least_privilege_role_on_the_workspace" {
  command = plan

  assert {
    condition     = azurerm_role_assignment.workspace[0].role_definition_name == "AzureML Data Scientist"
    error_message = "The project identity should get the AzureML Data Scientist role, nothing broader."
  }

  assert {
    condition     = endswith(azurerm_role_assignment.workspace[0].scope, "/workspaces/mlw-manufacturing")
    error_message = "The role must be limited to the department workspace."
  }
}

run "no_team_group_by_default" {
  command = plan

  assert {
    condition     = length(azuread_group.team) == 0 && length(azurerm_role_assignment.team) == 0
    error_message = "No Entra ID group unless create_team_group = true (it needs extra permissions)."
  }
}

run "team_group_on_request_gets_the_same_limited_role" {
  command = plan

  variables {
    create_team_group      = true
    team_member_object_ids = ["11111111-1111-1111-1111-111111111111"]
  }

  assert {
    condition     = azuread_group.team[0].display_name == "grp-ml-manufacturing-tool-wear"
    error_message = "Unexpected team group name."
  }

  assert {
    condition     = azurerm_role_assignment.team[0].role_definition_name == "AzureML Data Scientist"
    error_message = "The team group should get AzureML Data Scientist, never Owner or Contributor."
  }
}

run "data_domains_are_recorded" {
  command = plan

  variables {
    data_domains = ["production", "maintenance"]
  }

  assert {
    condition     = azurerm_user_assigned_identity.project.tags["data_domains"] == "production,maintenance"
    error_message = "The data domains should be visible as a tag."
  }

  assert {
    condition     = output.fabric_access_todo.read_data_domains == tolist(["production", "maintenance"])
    error_message = "The data domains should be listed in the Fabric to-do output."
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

# --- Optional environment and names from outside ---

run "default_names_without_environment" {
  command = plan

  assert {
    condition     = azurerm_user_assigned_identity.project.name == "id-ml-manufacturing-tool-wear"
    error_message = "Default identity name should be id-ml-<department>-<name>."
  }

  assert {
    condition     = !contains(keys(azurerm_user_assigned_identity.project.tags), "environment")
    error_message = "No environment tag unless an environment is given."
  }
}

run "environment_goes_into_names_and_tags" {
  command = plan

  variables {
    environment = "prod"
  }

  assert {
    condition     = azurerm_user_assigned_identity.project.name == "id-ml-manufacturing-tool-wear-prod"
    error_message = "With environment = prod the identity name should end with -prod."
  }

  assert {
    condition     = azurerm_user_assigned_identity.project.tags["environment"] == "prod"
    error_message = "The environment should be a tag."
  }
}

run "names_from_outside_win" {
  command = plan

  variables {
    names = {
      identity = "uai-mfg-toolwear-01"
      cluster  = "cpu-mfg-01"
    }
  }

  assert {
    condition     = azurerm_user_assigned_identity.project.name == "uai-mfg-toolwear-01"
    error_message = "An identity name given in var.names must be used as it is."
  }

  assert {
    condition     = output.compute_name == "cpu-mfg-01"
    error_message = "A cluster name given in var.names must be used as it is."
  }
}

run "rejects_too_long_cluster_name" {
  command = plan

  variables {
    names = {
      cluster = "cluster-name-way-too-long"
    }
  }

  expect_failures = [var.names]
}

run "no_github_login_rules_when_ml_project_github_makes_them" {
  command = plan

  variables {
    create_github_login = false
  }

  assert {
    condition     = length(azurerm_federated_identity_credential.github_main) == 0 && length(azurerm_federated_identity_credential.github_deploy) == 0
    error_message = "With create_github_login = false the GitHub login rules belong to ml-project-github."
  }
}
