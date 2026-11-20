# Values other code needs after `terraform apply`: the ml-project module
# (workspace_name, resource_group_name) and the project's jobs (cluster names).

output "workspace_name" {
  description = "Name of the Azure ML workspace. Input workspace_name of ml-project; GitHub variable AZURE_ML_WORKSPACE."
  value       = azurerm_machine_learning_workspace.this.name
}

output "workspace_id" {
  description = "Full Azure ID of the workspace."
  value       = azurerm_machine_learning_workspace.this.id
}

output "resource_group_name" {
  description = "Resource group of the workspace. GitHub variable AZURE_RESOURCE_GROUP."
  value       = var.resource_group_name
}

output "location" {
  description = "Azure region of the workspace (same as the resource group)."
  value       = local.location
}

output "cpu_cluster_name" {
  description = "CPU cluster to use in jobs/*.yml (compute: azureml:<name>)."
  value       = azurerm_machine_learning_compute_cluster.cpu.name
}

output "gpu_cluster_name" {
  description = "GPU cluster name, or null when gpu = false."
  value       = var.gpu ? azurerm_machine_learning_compute_cluster.gpu[0].name : null
}

output "resource_names" {
  description = "Names of the helper resources, to find them in the Azure portal."
  value       = local.names
}
