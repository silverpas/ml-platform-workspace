# Inputs: what the platform team fills in for each new use case.

variable "github_repo" {
  description = "The use case's repo, as \"org/repo\" (the same as ml-project's github_repo)."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$", var.github_repo))
    error_message = "github_repo must look like \"org/repo\"."
  }
}

variable "create_repo" {
  description = "true (default) = create the repo from template_repo. false = the repo already exists; the module only sets its variables and environment."
  type        = bool
  default     = true
}

variable "template_repo" {
  description = "The project template repo, as \"org/repo\" (e.g. example-org/ml-project-template). Only used when create_repo = true."
  type        = string
  default     = null

  validation {
    condition     = var.template_repo == null ? true : can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$", var.template_repo))
    error_message = "template_repo must look like \"org/repo\"."
  }
}

variable "visibility" {
  description = "Visibility of a new repo. private (default) keeps workflow logs, which show Azure names, out of public view."
  type        = string
  default     = "private"

  validation {
    condition     = contains(["private", "internal"], var.visibility)
    error_message = "visibility must be private or internal: a project repo's logs show Azure names."
  }
}

variable "description" {
  description = "Description of a new repo."
  type        = string
  default     = null
}

variable "azure" {
  description = "The five values the workflows need, from ml-project's outputs. Stored as GitHub variables (IDs, not secrets)."
  type = object({
    client_id       = string
    tenant_id       = string
    subscription_id = string
    resource_group  = string
    workspace       = string
  })
}

variable "identity_id" {
  description = "Full Azure ID of the project identity (ml-project output identity_id). The GitHub login rules are added to it. Set ml-project's create_github_login = false."
  type        = string
}

variable "deploy_environment" {
  description = "GitHub environment that holds the approval gate. Must match deploy.yml and ml-project's deploy_environment."
  type        = string
  default     = "production"
}

variable "reviewer_user_ids" {
  description = "GitHub user IDs who must approve a deploy (gh api users/<login> --jq .id). [] = no required reviewers. Private repos need a paid GitHub plan for reviewers."
  type        = list(number)
  default     = []
}

variable "reviewer_team_ids" {
  description = "GitHub team IDs who must approve a deploy. Same plan rule as reviewer_user_ids."
  type        = list(number)
  default     = []
}
