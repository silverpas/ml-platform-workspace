variable "registry_dir" {
  description = "Folder with ml_workspaces/ and ml_use_cases/. Default: ../registry next to this folder. Tests point it at fixtures."
  type        = string
  default     = null
}

variable "manage_github" {
  description = "true (default) = also create each use case's GitHub repo, its five variables and its approval environment (module ml-project-github). false = repos are set up by hand."
  type        = bool
  default     = true
}

variable "github_owner" {
  description = "GitHub organization that owns the project repos and the template."
  type        = string
  default     = "example-org" # ASSUMPTION: replace with the organization
}

variable "template_repo" {
  description = "The project template repo, as org/repo."
  type        = string
  default     = "example-org/ml-project-template" # ASSUMPTION: replace
}

# --- Settings for running this outside the real platform (e.g. a sandbox) ---

variable "create_role_assignments" {
  description = "true (default) = assign the projects' roles. false = whoever applies may not assign roles (e.g. Contributor in a sandbox); the roles_to_assign_by_hand of each project are then done by someone else."
  type        = bool
  default     = true
}

variable "extra_tags" {
  description = "Tags added to every resource, e.g. to count a sandbox in a budget."
  type        = map(string)
  default     = {}
}

variable "subscription_id" {
  description = "Azure subscription. null (default) = from the ARM_SUBSCRIPTION_ID environment variable, as the platform's workflow sets it."
  type        = string
  default     = null
}

variable "resource_provider_registrations" {
  description = "Which Azure services the provider registers in the subscription (azurerm setting). \"none\" when they are registered already."
  type        = string
  default     = "legacy"
}

variable "purge_key_vault_on_destroy" {
  description = "true = destroy really deletes a key vault (useful in a sandbox). false (default) keeps it soft-deleted for its retention days."
  type        = bool
  default     = false
}
