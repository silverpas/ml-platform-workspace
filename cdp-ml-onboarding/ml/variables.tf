variable "registry_dir" {
  description = "Folder with ml_workspaces/ and ml_use_cases/. Default: ../registry next to this folder. Tests point it at fixtures."
  type        = string
  default     = null
}
