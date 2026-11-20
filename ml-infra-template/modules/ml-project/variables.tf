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
  description = "Short name of the use case, e.g. \"machine-fail\". Max 13 characters because Azure limits compute cluster names to 16 (we add \"cc-\")."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,11}[a-z0-9]$", var.name))
    error_message = "name: 3-13 characters, lowercase letters, digits and hyphens, starting with a letter and not ending with a hyphen."
  }
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

# --- Compute ---

variable "gpu" {
  description = "true = GPU machines for this project (needs GPU quota from Microsoft first)."
  type        = bool
  default     = false
}

variable "cpu_vm_size" {
  description = "Machine type when gpu = false."
  type        = string
  default     = "Standard_DS3_v2"
}

variable "gpu_vm_size" {
  description = "Machine type when gpu = true."
  type        = string
  default     = "Standard_NC4as_T4_v3"
}

variable "max_nodes" {
  description = "Most machines the cluster may start at once. It always scales back to 0 when idle."
  type        = number
  default     = 2

  validation {
    condition     = var.max_nodes >= 1 && var.max_nodes <= 10
    error_message = "max_nodes must be between 1 and 10."
  }
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
