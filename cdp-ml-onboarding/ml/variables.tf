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
