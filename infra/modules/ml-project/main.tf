# What one ML use case gets inside its department's Azure ML workspace:
#   1. an identity (a "robot account") for the project's GitHub workflows,
#   2. permission for GitHub to log in as that identity, without secrets (OIDC),
#   3. permission for that identity to run jobs and register models in the workspace,
#   4. its own compute cluster, which scales to 0 machines when idle.

# The department workspace already exists (created by the platform team).
# "data" means: look it up, don't create it.
data "azurerm_machine_learning_workspace" "department" {
  name                = var.workspace_name
  resource_group_name = var.workspace_resource_group_name
}

locals {
  project_id = "${var.department}-${var.name}" # e.g. manufacturing-machine-fail
  location   = data.azurerm_machine_learning_workspace.department.location
  vm_size    = var.gpu ? var.gpu_vm_size : var.cpu_vm_size

  tags = merge(var.tags, {
    department = var.department
    use_case   = var.name
    owner      = var.owner
    managed_by = "terraform"
  })

  # GitHub's login service, and the audience Azure expects for it.
  github_issuer   = "https://token.actions.githubusercontent.com"
  github_audience = ["api://AzureADTokenExchange"]
}

# 1. The project's identity.
resource "azurerm_user_assigned_identity" "project" {
  name                = "id-ml-${local.project_id}"
  location            = local.location
  resource_group_name = var.workspace_resource_group_name
  tags                = local.tags
}

# 2a. GitHub may log in as the identity when a workflow runs on the main branch
#     (used by train.yml).
resource "azurerm_federated_identity_credential" "github_main" {
  name                      = "github-main"
  user_assigned_identity_id = azurerm_user_assigned_identity.project.id
  issuer                    = local.github_issuer
  audience                  = local.github_audience
  subject                   = "repo:${var.github_repo}:ref:refs/heads/main"
}

# 2b. ...and when a workflow runs in the approval-gated environment
#     (used by deploy.yml, only after a reviewer approved).
resource "azurerm_federated_identity_credential" "github_deploy" {
  name                      = "github-${var.deploy_environment}"
  user_assigned_identity_id = azurerm_user_assigned_identity.project.id
  issuer                    = local.github_issuer
  audience                  = local.github_audience
  subject                   = "repo:${var.github_repo}:environment:${var.deploy_environment}"
}

# 3. Permission to submit jobs and register models in the workspace.
#    "AzureML Data Scientist" cannot create or delete compute or change the workspace.
resource "azurerm_role_assignment" "workspace" {
  scope                = data.azurerm_machine_learning_workspace.department.id
  role_definition_name = "AzureML Data Scientist"
  principal_id         = azurerm_user_assigned_identity.project.principal_id
  principal_type       = "ServicePrincipal"
}

# 4. The project's compute cluster.
resource "azurerm_machine_learning_compute_cluster" "project" {
  name                          = "cc-${var.name}"
  location                      = local.location
  machine_learning_workspace_id = data.azurerm_machine_learning_workspace.department.id
  vm_size                       = local.vm_size
  vm_priority                   = "Dedicated"
  tags                          = local.tags

  scale_settings {
    min_node_count                       = 0 # no machines (and no cost) when idle
    max_node_count                       = var.max_nodes
    scale_down_nodes_after_idle_duration = "PT15M" # stop machines after 15 idle minutes
  }

  # Jobs on this cluster run as the project identity, so the platform team
  # can give exactly this identity access to the Fabric data it needs.
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.project.id]
  }
}
