# Inputs: what the platform team fills in for each new use case.

# --- About the use case ---

variable "department" {
  description = "Department that owns the use case, e.g. \"manufacturing\". Used in names and tags."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,19}$", var.department))
    error_message = "department: 2-20 characters, lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "name" {
  description = "Short name of the use case, e.g. \"tool-wear\". The same name as the model, the repo (ml-<name>) and the OneLake folder."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,22}[a-z0-9]$", var.name))
    error_message = "name: 3-24 characters, lowercase letters, digits and hyphens, starting with a letter and not ending with a hyphen."
  }
}

variable "environment" {
  description = "Optional, e.g. \"dev\" or \"prod\", the same as the workspace's. null (default) = no environment, one workspace per department. Added to names and tags."
  type        = string
  default     = null

  validation {
    condition     = var.environment == null ? true : can(regex("^[a-z][a-z0-9]{1,4}$", var.environment))
    error_message = "environment: 2-5 lowercase letters or digits, e.g. dev, test, prod."
  }
}

variable "names" {
  description = "Optional: your own names, when the platform has naming rules. Left out = the module's default (id-ml-<department>-<name>, grp-ml-<department>-<name>)."
  type = object({
    identity   = optional(string)
    team_group = optional(string)
  })
  default = {}
}

variable "owner" {
  description = "Model owner (a person or team). Stored as a tag so everyone knows who to ask."
  type        = string

  validation {
    condition     = length(trimspace(var.owner)) > 0
    error_message = "owner must not be empty."
  }
}

variable "github_repo" {
  description = "GitHub repository of the use case, as \"org/repo\". Only workflows from this repo can log in to Azure."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$", var.github_repo))
    error_message = "github_repo must look like \"org/repo\"."
  }
}

# --- Where it plugs in (created by the platform team, not by this module) ---

variable "workspace_name" {
  description = "Name of the department's existing Azure ML workspace."
  type        = string
}

variable "workspace_resource_group_name" {
  description = "Resource group of that workspace. The project identity is created here too."
  type        = string
}

# --- Compute (the clusters are created by the ml-workspace module) ---

variable "gpu" {
  description = "true = this project trains on the department's GPU cluster (ml-workspace with gpu = true). Changes only the compute_name output."
  type        = bool
  default     = false
}

variable "compute_name" {
  description = "Optional: the cluster the project's jobs use, e.g. ml-workspace's cpu_cluster_name output. null = \"gpu-cluster\" or \"cpu-cluster\", depending on gpu."
  type        = string
  default     = null
}

# --- Data (placeholders until the Fabric side is clear) ---

variable "data_domains" {
  description = "Fabric data domains this project reads, e.g. [\"production\"]. Recorded as a tag and in the fabric_access_todo output; access is granted in Fabric by hand."
  type        = list(string)
  default     = []
}

# --- Team (optional: needs permission to create Entra ID groups) ---

variable "create_team_group" {
  description = "true = create an Entra ID group for the project team with the AzureML Data Scientist role on the workspace. Needs permission to create groups (often only IT has it)."
  type        = bool
  default     = false
}

variable "team_member_object_ids" {
  description = "Entra ID object IDs of the team members (only used when create_team_group = true)."
  type        = list(string)
  default     = []
}

# --- GitHub ---

variable "deploy_environment" {
  description = "GitHub environment that holds the approval gate (required reviewers). Must match deploy.yml."
  type        = string
  default     = "production"
}

variable "tags" {
  description = "Extra tags to add to every resource."
  type        = map(string)
  default     = {}
}
