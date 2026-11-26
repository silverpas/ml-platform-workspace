# What one ML project gets inside its Azure ML workspace (by default the
# project's own, in its own resource group: see the ml-workspace module):
#   1. an identity (a "robot account") for the project's GitHub workflows and jobs,
#   2. permission for GitHub to log in as that identity, without secrets (OIDC),
#   3. permission for that identity to run jobs and register models in the workspace,
#   4. the project's own compute cluster, running as that identity and tagged
#      with the use case (data access and costs per project), scaling to 0,
#   5. optionally, an Entra ID group for the team with the same permission.

# The workspace already exists (created with the ml-workspace module).
# Best: pass its ID and region from ml-workspace's outputs (workspace_id,
# location, lookup_workspace = false). Otherwise the module looks the workspace
# up by name ("data" = read, don't create). Passing them avoids a trap: when the
# workspace has any pending change, the lookup waits until apply, its region
# becomes "unknown" and Terraform would replace the identity and cluster.
data "azurerm_machine_learning_workspace" "department" {
  count = var.lookup_workspace ? 1 : 0

  name                = var.workspace_name
  resource_group_name = var.workspace_resource_group_name
}

locals {
  # e.g. manufacturing-tool-wear, or manufacturing-tool-wear-dev with an environment
  project_id   = "${var.department}-${var.name}${var.environment == null ? "" : "-${var.environment}"}"
  workspace_id = var.lookup_workspace ? data.azurerm_machine_learning_workspace.department[0].id : var.workspace_id
  location     = var.lookup_workspace ? data.azurerm_machine_learning_workspace.department[0].location : var.location

  # A name given in var.names wins; otherwise the default.
  names = {
    identity   = coalesce(var.names.identity, "id-ml-${local.project_id}")
    team_group = coalesce(var.names.team_group, "grp-ml-${local.project_id}")
    cluster    = coalesce(var.names.cluster, local.default_cluster_name)
  }

  # Azure ML cluster names have at most 16 characters: "cpu-tool-wear" fits;
  # a longer one becomes its first 9 characters + 6 characters derived from it.
  cluster_base         = "${var.gpu ? "gpu" : "cpu"}-${var.name}${var.environment == null ? "" : "-${var.environment}"}"
  default_cluster_name = length(local.cluster_base) <= 16 ? local.cluster_base : "${trimsuffix(substr(local.cluster_base, 0, 9), "-")}-${substr(md5(local.cluster_base), 0, 6)}"

  vm_size = coalesce(var.vm_size, var.gpu ? "Standard_NC4as_T4_v3" : "Standard_DS3_v2")

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

  # How the repo appears in GitHub's OIDC subject: "org/repo", or with numeric
  # IDs "org@123/repo@456" when GitHub includes them (see var.github_ids).
  github_subject_repo = var.github_ids == null ? var.github_repo : format(
    "%s@%d/%s@%d",
    split("/", var.github_repo)[0], var.github_ids.owner_id,
    split("/", var.github_repo)[1], var.github_ids.repo_id,
  )
}

# 1. The project's identity.
resource "azurerm_user_assigned_identity" "project" {
  name                = local.names.identity
  location            = local.location
  resource_group_name = var.workspace_resource_group_name
  tags                = local.tags
}

# 2a. GitHub may log in as the identity when a workflow runs on the main branch
#     (used by train.yml). Skipped when ml-project-github creates these rules
#     (create_github_login = false): it knows the repo's numeric IDs.
resource "azurerm_federated_identity_credential" "github_main" {
  count = var.create_github_login ? 1 : 0

  name                      = "github-main"
  user_assigned_identity_id = azurerm_user_assigned_identity.project.id
  issuer                    = local.github_issuer
  audience                  = local.github_audience
  subject                   = "repo:${local.github_subject_repo}:ref:refs/heads/main"
}

# 2b. ...and when a workflow runs in the approval-gated environment
#     (used by deploy.yml, only after a reviewer approved).
resource "azurerm_federated_identity_credential" "github_deploy" {
  count = var.create_github_login ? 1 : 0

  name                      = "github-${var.deploy_environment}"
  user_assigned_identity_id = azurerm_user_assigned_identity.project.id
  issuer                    = local.github_issuer
  audience                  = local.github_audience
  subject                   = "repo:${local.github_subject_repo}:environment:${var.deploy_environment}"
}

# 3. Permission to submit jobs and register models in the workspace.
#    "AzureML Data Scientist" cannot create or delete compute or change the workspace.
resource "azurerm_role_assignment" "workspace" {
  count = var.create_role_assignments ? 1 : 0

  scope                = local.workspace_id
  role_definition_name = "AzureML Data Scientist"
  principal_id         = azurerm_user_assigned_identity.project.principal_id
  principal_type       = "ServicePrincipal"
}

# 3b. The cluster loads the job environments (Docker images) from the workspace's
#     registry with this identity, because the registry has no admin password.
#     ASSUMPTION: AcrPull is all the cluster identity needs; check in a sandbox.
resource "azurerm_role_assignment" "registry" {
  count = var.create_role_assignments ? 1 : 0

  scope                = var.container_registry_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.project.principal_id
  principal_type       = "ServicePrincipal"

  lifecycle {
    precondition {
      condition     = var.container_registry_id != null
      error_message = "container_registry_id is needed to give the cluster AcrPull (or set create_role_assignments = false)."
    }
  }
}

# 4. The project's own cluster. Jobs run as the project identity, so later the
#    project reaches only the Fabric data granted to that identity (design section 9).
resource "azurerm_machine_learning_compute_cluster" "project" {
  name                          = local.names.cluster
  location                      = local.location
  machine_learning_workspace_id = local.workspace_id
  vm_size                       = local.vm_size
  vm_priority                   = "Dedicated"
  tags                          = local.tags # use_case tag: costs per project in Cost Management

  scale_settings {
    min_node_count                       = 0 # no machines, no cost when idle
    max_node_count                       = var.max_nodes
    scale_down_nodes_after_idle_duration = "PT${var.idle_minutes_before_scale_down}M"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.project.id]
  }
}

# 5. Optional team group with the same limited role (never Owner or Contributor).
resource "azuread_group" "team" {
  count = var.create_team_group ? 1 : 0

  display_name     = local.names.team_group
  description      = "Team of ML use case ${var.name} (${var.department}). Owner: ${var.owner}."
  security_enabled = true
  members          = var.team_member_object_ids
}

resource "azurerm_role_assignment" "team" {
  count = var.create_team_group && var.create_role_assignments ? 1 : 0

  scope                = local.workspace_id
  role_definition_name = "AzureML Data Scientist"
  principal_id         = azuread_group.team[0].object_id
  principal_type       = "Group"
}
