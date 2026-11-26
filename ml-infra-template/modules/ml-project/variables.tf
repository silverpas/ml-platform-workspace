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
  description = "Optional, e.g. \"dev\" or \"prod\", the same as the workspace's. null (default) = no environment. Added to names and tags."
  type        = string
  default     = null

  validation {
    condition     = var.environment == null ? true : can(regex("^[a-z][a-z0-9]{1,4}$", var.environment))
    error_message = "environment: 2-5 lowercase letters or digits, e.g. dev, test, prod."
  }
}

variable "names" {
  description = "Optional: your own names, when the platform has naming rules. Left out = the module's default (id-ml-<department>-<name>, grp-ml-<department>-<name>, cpu-<name> or gpu-<name>)."
  type = object({
    identity   = optional(string)
    team_group = optional(string)
    cluster    = optional(string)
  })
  default = {}

  validation {
    condition     = var.names.cluster == null ? true : can(regex("^[a-zA-Z][a-zA-Z0-9-]{1,15}$", var.names.cluster))
    error_message = "names.cluster: 2-16 characters, letters, digits and hyphens, starting with a letter (Azure ML's rule)."
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

variable "create_github_login" {
  description = "true (default) = this module creates the two GitHub login rules (federated credentials). false = module ml-project-github creates them (it reads the repo's numeric IDs itself)."
  type        = bool
  default     = true
}

variable "github_ids" {
  description = "Optional: the numeric IDs of the repo's owner and of the repo. GitHub may put them in the OIDC subject (repo:<owner>@<owner_id>/<repo>@<repo_id>:...); the login error message shows which form it uses. Find them with: gh api repos/<org>/<repo> --jq '.owner.id, .id'. null (default) = subject without IDs."
  type = object({
    owner_id = number
    repo_id  = number
  })
  default = null
}

# --- Where it plugs in (created by the platform team, not by this module) ---

variable "workspace_name" {
  description = "Name of the project's existing Azure ML workspace (ml-workspace output workspace_name)."
  type        = string
}

variable "lookup_workspace" {
  description = "true (default) = look the workspace up by name. false (recommended when ml-workspace runs in the same Terraform) = use workspace_id and location instead, so a change to the workspace never forces Terraform to replace the identity and cluster."
  type        = bool
  default     = true
}

variable "workspace_id" {
  description = "Full Azure ID of the workspace (ml-workspace output workspace_id). Used when lookup_workspace = false."
  type        = string
  default     = null
}

variable "location" {
  description = "The workspace's Azure region (ml-workspace output location). Used when lookup_workspace = false."
  type        = string
  default     = null
}

variable "workspace_resource_group_name" {
  description = "Resource group of that workspace. The project identity is created here too."
  type        = string
}

variable "container_registry_id" {
  description = "Full ID of the workspace's container registry (ml-workspace output container_registry_id). The project's cluster gets AcrPull on it, to load the job environments. Required when create_role_assignments = true."
  type        = string
  default     = null
}

# --- Compute: the project's own cluster ---

variable "gpu" {
  description = "true = a GPU cluster instead of a CPU one. Needs GPU quota from Microsoft first."
  type        = bool
  default     = false
}

variable "vm_size" {
  description = "Machine type of the cluster. null = Standard_DS3_v2 (4 cores, 14 GB) for CPU, Standard_NC4as_T4_v3 (1 small T4 GPU) for GPU. Must fit the subscription's quota."
  type        = string
  default     = null
}

variable "max_nodes" {
  description = "Most machines that may run at once. The cluster always scales back to 0 when idle."
  type        = number
  default     = 1

  validation {
    condition     = var.max_nodes >= 1 && var.max_nodes <= 10
    error_message = "max_nodes must be between 1 and 10."
  }
}

variable "idle_minutes_before_scale_down" {
  description = "Minutes a machine may sit idle before it is switched off (also used in the project's cost estimate)."
  type        = number
  default     = 15

  validation {
    condition     = var.idle_minutes_before_scale_down >= 1 && var.idle_minutes_before_scale_down <= 120
    error_message = "idle_minutes_before_scale_down must be between 1 and 120."
  }
}

# --- Data (placeholders until the Fabric side is clear) ---

variable "data_domains" {
  description = "Fabric data domains this project reads, e.g. [\"production\"]. Recorded as a tag and in the fabric_access_todo output; access is granted in Fabric by hand."
  type        = list(string)
  default     = []
}

# --- Permissions ---

variable "create_role_assignments" {
  description = "true (default) = give the identity its roles (AzureML Data Scientist on the workspace, AcrPull on the registry). Needs Owner, User Access Administrator or Role Based Access Control Administrator. false = someone with that right assigns them by hand (e.g. a personal sandbox)."
  type        = bool
  default     = true
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
