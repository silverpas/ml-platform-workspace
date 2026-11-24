# Tests for the registry-driven root. Run with:
#   terraform -chdir=ml init -backend=false
#   terraform -chdir=ml test
#
# Mock providers replace Azure and Entra ID: no login, no cost, nothing created.
# Each run points `registry_dir` at a small example registry in tests/fixtures/.

mock_provider "azurerm" {
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

  mock_data "azurerm_machine_learning_workspace" {
    defaults = {
      id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ml-manufacturing/providers/Microsoft.MachineLearningServices/workspaces/mlw-manufacturing"
      location = "swedencentral"
    }
  }
}

mock_provider "azuread" {}

run "the_real_example_registry_plans" {
  command = plan

  assert {
    condition     = keys(module.ml_workspace) == ["manufacturing"]
    error_message = "registry/ml_workspaces/manufacturing.yaml should give one workspace."
  }

  assert {
    condition     = keys(module.ml_project) == ["manufacturing__tool-wear"]
    error_message = "registry/ml_use_cases/manufacturing__tool-wear.yaml should give one project."
  }

  assert {
    condition     = output.registry_checks == "ok: 1 ML workspace(s), 1 active use case(s)"
    error_message = "The example registry should pass every check."
  }
}

run "one_file_per_use_case_retired_ones_get_nothing" {
  command = plan

  variables {
    registry_dir = "tests/fixtures/two_use_cases"
  }

  assert {
    condition     = toset(keys(module.ml_project)) == toset(["manufacturing__tool-wear", "manufacturing__spindle-temp"])
    error_message = "Two active files should give two projects; the retired one none."
  }

  assert {
    condition     = length(module.ml_workspace) == 1
    error_message = "Both use cases share the department's one workspace."
  }
}

run "use_case_without_department_workspace_is_refused" {
  command = plan

  variables {
    registry_dir = "tests/fixtures/missing_workspace"
  }

  expect_failures = [output.registry_checks]
}

run "file_name_must_match_the_content" {
  command = plan

  variables {
    registry_dir = "tests/fixtures/wrong_file_name"
  }

  expect_failures = [output.registry_checks]
}
