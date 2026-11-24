# Inputs: what the platform team fills in, once per department.

variable "department" {
  description = "Department that owns the workspace, e.g. \"manufacturing\". Used in names and tags."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,19}$", var.department))
    error_message = "department: 2-20 characters, lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "resource_group_name" {
  description = "Existing resource group to create everything in. The module does not create it, so it fits however the platform team organizes resource groups."
  type        = string
}

variable "environment" {
  description = "Optional, e.g. \"dev\" or \"prod\". null (default) = one workspace per department, the recommended setup: the approval gate (candidate -> champion) already separates tested from untested models. Set it only if the platform's rules require separate environments; it is added to names and tags."
  type        = string
  default     = null

  validation {
    condition     = var.environment == null ? true : can(regex("^[a-z][a-z0-9]{1,4}$", var.environment))
    error_message = "environment: 2-5 lowercase letters or digits, e.g. dev, test, prod."
  }
}

variable "names" {
  description = "Optional: your own resource names, when the platform has naming rules (often defined in one central place). Any name left out uses the module's default (see README)."
  type = object({
    workspace          = optional(string)
    storage_account    = optional(string)
    key_vault          = optional(string)
    container_registry = optional(string)
    log_analytics      = optional(string)
    app_insights       = optional(string)
  })
  default = {}

  # Azure's own rules for the names that must be unique in all of Azure.
  validation {
    condition     = var.names.storage_account == null ? true : can(regex("^[a-z0-9]{3,24}$", var.names.storage_account))
    error_message = "names.storage_account: 3-24 lowercase letters or digits, no hyphens."
  }

  validation {
    condition     = var.names.key_vault == null ? true : can(regex("^[a-zA-Z][a-zA-Z0-9-]{1,22}[a-zA-Z0-9]$", var.names.key_vault))
    error_message = "names.key_vault: 3-24 letters, digits or hyphens, starting with a letter."
  }

  validation {
    condition     = var.names.container_registry == null ? true : can(regex("^[a-zA-Z0-9]{5,50}$", var.names.container_registry))
    error_message = "names.container_registry: 5-50 letters or digits, no hyphens."
  }
}

variable "owner" {
  description = "Who is responsible for this workspace (a person or team). Stored as a tag."
  type        = string

  validation {
    condition     = length(trimspace(var.owner)) > 0
    error_message = "owner must not be empty."
  }
}

# --- Network ---

variable "public_network_access" {
  description = "true = the workspace is reachable from the internet (still behind Entra ID login). Fine for a sandbox with public data."
  type        = bool
  # ASSUMPTION: production setups usually require private endpoints instead;
  # the platform team decides. This module does not create private networking.
  default = true
}

variable "tags" {
  description = "Extra tags to add to every resource."
  type        = map(string)
  default     = {}
}
