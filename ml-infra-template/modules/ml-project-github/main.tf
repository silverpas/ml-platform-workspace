# What one ML use case gets on GitHub, so it is ready to run without manual steps:
#   1. its repo, created from the project template (or an existing repo),
#   2. the five Azure IDs as GitHub variables (the workflows log in with them),
#   3. the approval-gated environment for deploy.yml, with its reviewers,
#   4. the two Azure login rules (federated credentials) on the project identity,
#      written exactly as GitHub sends its OIDC subject, numeric IDs included.
# Call ml-project first (with create_github_login = false), then this module.

locals {
  owner     = split("/", var.github_repo)[0]
  repo_name = split("/", var.github_repo)[1]

  variables = {
    AZURE_CLIENT_ID       = var.azure.client_id
    AZURE_TENANT_ID       = var.azure.tenant_id
    AZURE_SUBSCRIPTION_ID = var.azure.subscription_id
    AZURE_RESOURCE_GROUP  = var.azure.resource_group
    AZURE_ML_WORKSPACE    = var.azure.workspace
  }

  repo_id  = var.create_repo ? github_repository.project[0].repo_id : data.github_repository.existing[0].repo_id
  owner_id = jsondecode(data.github_rest_api.owner.body).id

  # How GitHub names the repo in its OIDC subject: org@<owner_id>/repo@<repo_id>.
  subject_repo = "${local.owner}@${local.owner_id}/${local.repo_name}@${local.repo_id}"

  github_issuer   = "https://token.actions.githubusercontent.com"
  github_audience = ["api://AzureADTokenExchange"]
}

# 1a. A new repo from the template.
resource "github_repository" "project" {
  count = var.create_repo ? 1 : 0

  name        = local.repo_name
  description = var.description
  visibility  = var.visibility
  has_issues  = true # review-reminder.yml opens issues

  # Destroying the module archives the repo (read-only) instead of deleting it.
  archive_on_destroy = true

  template {
    owner      = split("/", var.template_repo)[0]
    repository = split("/", var.template_repo)[1]
  }

  lifecycle {
    precondition {
      condition     = var.template_repo != null
      error_message = "template_repo is needed to create the repo (or set create_repo = false)."
    }
  }
}

# 1b. ...or an existing repo, looked up (data = read, don't change).
data "github_repository" "existing" {
  count     = var.create_repo ? 0 : 1
  full_name = var.github_repo
}

# The owner's numeric ID (works for a user and an organization).
data "github_rest_api" "owner" {
  endpoint = "users/${local.owner}"
}

# 2. The five GitHub variables.
resource "github_actions_variable" "azure" {
  for_each = local.variables

  repository    = local.repo_name
  variable_name = each.key
  value         = each.value

  depends_on = [github_repository.project]
}

# 3. The approval gate. Without reviewers the environment still exists (the
#    Azure login rule for deploy.yml needs it), but deploy.yml does not wait.
resource "github_repository_environment" "deploy" {
  repository          = local.repo_name
  environment         = var.deploy_environment
  prevent_self_review = false # in a small team the owner may approve

  dynamic "reviewers" {
    for_each = length(var.reviewer_user_ids) + length(var.reviewer_team_ids) > 0 ? [1] : []
    content {
      users = var.reviewer_user_ids
      teams = var.reviewer_team_ids
    }
  }

  depends_on = [github_repository.project]
}

# 4a. GitHub may log in as the project identity when a workflow runs on the
#     main branch (train.yml, score.yml)...
resource "azurerm_federated_identity_credential" "github_main" {
  name                      = "github-main"
  user_assigned_identity_id = var.identity_id
  issuer                    = local.github_issuer
  audience                  = local.github_audience
  subject                   = "repo:${local.subject_repo}:ref:refs/heads/main"
}

# 4b. ...and in the approval-gated environment (deploy.yml, after approval).
resource "azurerm_federated_identity_credential" "github_deploy" {
  name                      = "github-${var.deploy_environment}"
  user_assigned_identity_id = var.identity_id
  issuer                    = local.github_issuer
  audience                  = local.github_audience
  subject                   = "repo:${local.subject_repo}:environment:${var.deploy_environment}"
}
