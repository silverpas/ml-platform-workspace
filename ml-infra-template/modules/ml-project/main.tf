# What one ML use case gets inside its department's Azure ML workspace:
#   1. an identity (a "robot account") for the project's GitHub workflows,
#   2. permission for GitHub to log in as that identity, without secrets (OIDC),
#   3. permission for that identity to run jobs and register models in the workspace,
#   4. optionally, an Entra ID group for the team with the same permission.
# Compute clusters are shared and come from the ml-workspace module.

# The department workspace already exists (created with the ml-workspace module).
# "data" means: look it up, don't create it.
data "azurerm_machine_learning_workspace" "department" {
  name                = var.workspace_name
  resource_group_name = var.workspace_resource_group_name
}

locals {
  # e.g. manufacturing-tool-wear, or manufacturing-tool-wear-dev with an environment
  project_id = "${var.department}-${var.name}${var.environment == null ? "" : "-${var.environment}"}"
  location   = data.azurerm_machine_learning_workspace.department.location

  # A name given in var.names wins; otherwise the default.
  names = {
    identity   = coalesce(var.names.identity, "id-ml-${local.project_id}")
    team_group = coalesce(var.names.team_group, "grp-ml-${local.project_id}")
  }

  tags = merge(var.tags, {
    department   = var.department
    use_case     = var.name
    owner        = var.owner
    data_domains = join(",", var.data_domains)
    managed_by   = "terraform"
  }, var.environment == null ? {} : { environment = var.environment })

  # GitHub's login service, and the audience Azure expects for it.
  github_issuer   = "https://token.actions.githubusercontent.com"
  github_audience = ["api://AzureADTokenExchange"]
}

# 1. The project's identity.
resource "azurerm_user_assigned_identity" "project" {
  name                = local.names.identity
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

# 4. Optional team group with the same limited role (never Owner or Contributor).
resource "azuread_group" "team" {
  count = var.create_team_group ? 1 : 0

  display_name     = local.names.team_group
  description      = "Team of ML use case ${var.name} (${var.department}). Owner: ${var.owner}."
  security_enabled = true
  members          = var.team_member_object_ids
}

resource "azurerm_role_assignment" "team" {
  count = var.create_team_group ? 1 : 0

  scope                = data.azurerm_machine_learning_workspace.department.id
  role_definition_name = "AzureML Data Scientist"
  principal_id         = azuread_group.team[0].object_id
  principal_type       = "Group"
}
