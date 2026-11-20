# Tests for the ml-workspace module. Run with:
#   terraform -chdir=modules/ml-workspace init -backend=false
#   terraform -chdir=modules/ml-workspace test
#
# `mock_provider` replaces Azure with a fake: no login, no cost, nothing is created.
# Each `run` makes a plan and checks what WOULD be created.

mock_provider "azurerm" {
  # The fake existing resource group the module looks up.
  mock_data "azurerm_resource_group" {
    defaults = {
      id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ml-manufacturing"
      location = "swedencentral"
    }
  }

  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id = "00000000-0000-0000-0000-000000000000"
    }
  }
}

variables {
  department          = "manufacturing"
  resource_group_name = "rg-ml-manufacturing"
  owner               = "ml-platform-team"
}

run "cpu_cluster_scales_to_zero" {
  command = plan

  assert {
    condition     = azurerm_machine_learning_compute_cluster.cpu.name == "cpu-cluster"
    error_message = "The CPU cluster must be called cpu-cluster: the project template's jobs use that name."
  }

  assert {
    condition     = azurerm_machine_learning_compute_cluster.cpu.scale_settings[0].min_node_count == 0
    error_message = "The CPU cluster must scale to 0 machines so it costs nothing when idle."
  }

  assert {
    condition     = azurerm_machine_learning_compute_cluster.cpu.scale_settings[0].scale_down_nodes_after_idle_duration == "PT15M"
    error_message = "Idle machines should be switched off after 15 minutes by default."
  }
}

run "no_gpu_by_default" {
  command = plan

  assert {
    condition     = length(azurerm_machine_learning_compute_cluster.gpu) == 0
    error_message = "No GPU cluster unless gpu = true."
  }
}

run "gpu_on_request" {
  command = plan

  variables {
    gpu = true
  }

  assert {
    condition     = azurerm_machine_learning_compute_cluster.gpu[0].vm_size == "Standard_NC4as_T4_v3"
    error_message = "With gpu = true a GPU cluster should be created."
  }

  assert {
    condition     = azurerm_machine_learning_compute_cluster.gpu[0].scale_settings[0].min_node_count == 0
    error_message = "The GPU cluster must also scale to 0."
  }
}

run "everything_is_in_the_given_resource_group" {
  command = plan

  assert {
    condition = alltrue([
      azurerm_machine_learning_workspace.this.resource_group_name == "rg-ml-manufacturing",
      azurerm_storage_account.workspace.resource_group_name == "rg-ml-manufacturing",
      azurerm_key_vault.workspace.resource_group_name == "rg-ml-manufacturing",
      azurerm_container_registry.workspace.resource_group_name == "rg-ml-manufacturing",
    ])
    error_message = "Every resource must go into the given resource group."
  }

  assert {
    condition     = azurerm_machine_learning_workspace.this.location == "swedencentral"
    error_message = "The workspace should use the resource group's region."
  }
}

run "globally_unique_names_fit_azure_limits" {
  command = plan

  assert {
    condition = alltrue([
      can(regex("^[a-z0-9]{3,24}$", azurerm_storage_account.workspace.name)),
      can(regex("^[a-z0-9]{5,50}$", azurerm_container_registry.workspace.name)),
      length(azurerm_key_vault.workspace.name) <= 24,
    ])
    error_message = "Storage account, registry and key vault names must fit Azure's naming rules."
  }

  assert {
    condition     = azurerm_machine_learning_workspace.this.name == "mlw-manufacturing"
    error_message = "Unexpected workspace name."
  }
}

run "long_department_names_still_fit" {
  command = plan

  variables {
    department = "research-and-develop"
  }

  assert {
    condition = alltrue([
      can(regex("^[a-z0-9]{3,24}$", azurerm_storage_account.workspace.name)),
      length(azurerm_key_vault.workspace.name) <= 24,
    ])
    error_message = "Names must stay within 24 characters for the longest allowed department."
  }
}

run "safe_and_cheap_defaults" {
  command = plan

  assert {
    condition     = azurerm_container_registry.workspace.sku == "Basic" && !azurerm_container_registry.workspace.admin_enabled
    error_message = "The registry should be the cheapest tier, without a shared admin password."
  }

  assert {
    condition     = !azurerm_storage_account.workspace.allow_nested_items_to_be_public
    error_message = "Nothing in the storage account may be made public."
  }

  assert {
    condition     = azurerm_key_vault.workspace.rbac_authorization_enabled
    error_message = "The key vault should use Azure roles for access."
  }
}

run "tags_show_owner_and_department" {
  command = plan

  assert {
    condition     = azurerm_machine_learning_workspace.this.tags["owner"] == "ml-platform-team" && azurerm_machine_learning_workspace.this.tags["department"] == "manufacturing"
    error_message = "Every resource should be tagged with its owner and department."
  }
}

run "rejects_bad_department" {
  command = plan

  variables {
    department = "Manufacturing Dept"
  }

  expect_failures = [var.department]
}
