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

mock_provider "github" {
  mock_data "github_rest_api" {
    defaults = {
      body = "{\"id\": 123}"
    }
  }
}

run "the_real_example_registry_plans" {
  command = plan

  assert {
    condition     = keys(module.ml_project) == ["manufacturing__tool-wear"] && keys(module.ml_project_github) == ["manufacturing__tool-wear"]
    error_message = "registry/ml_use_cases/manufacturing__tool-wear.yaml should give one project, Azure and GitHub side."
  }

  assert {
    condition     = output.registry_checks == "ok: 1 active ML project(s)"
    error_message = "The example registry should pass every check."
  }
}

run "each_project_gets_its_own_resource_group_and_workspace" {
  command = plan

  assert {
    condition     = azurerm_resource_group.project["manufacturing__tool-wear"].name == "rg-ml-manufacturing-tool-wear" && azurerm_resource_group.project["manufacturing__tool-wear"].location == "swedencentral"
    error_message = "A project without resource_group gets rg-ml-<department>-<use_case> in the default region."
  }

  assert {
    condition     = keys(module.ml_workspace) == ["manufacturing__tool-wear"]
    error_message = "Each project gets its own workspace."
  }

  assert {
    condition     = azurerm_resource_group.project["manufacturing__tool-wear"].tags["use_case"] == "tool-wear"
    error_message = "The resource group should be tagged with its use case."
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
    condition     = length(module.ml_workspace) == 2 && length(azurerm_resource_group.project) == 2
    error_message = "Two projects, two resource groups, two workspaces."
  }
}

run "an_existing_resource_group_is_used_not_created" {
  command = plan

  variables {
    registry_dir = "tests/fixtures/existing_resource_group"
  }

  assert {
    condition     = length(azurerm_resource_group.project) == 0
    error_message = "A project that names an existing resource group must not create one."
  }

  assert {
    condition     = output.project_resource_groups["manufacturing__tool-wear"] == "rg-existing-ml"
    error_message = "The project must use the resource group named in its file."
  }
}

run "two_projects_in_one_resource_group_are_refused" {
  command = plan

  variables {
    registry_dir = "tests/fixtures/shared_resource_group"
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

run "github_by_hand_when_manage_github_is_off" {
  command = plan

  variables {
    manage_github = false
  }

  assert {
    condition     = length(module.ml_project_github) == 0
    error_message = "With manage_github = false no GitHub resources may be planned."
  }
}

run "repo_of_another_owner_is_refused" {
  command = plan

  variables {
    github_owner = "another-org"
  }

  expect_failures = [output.registry_checks]
}
