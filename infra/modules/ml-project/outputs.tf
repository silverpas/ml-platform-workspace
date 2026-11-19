# Values the platform team hands to the project team after `terraform apply`.
# The first four go into the GitHub repo as *variables* (Settings -> Secrets and
# variables -> Actions -> Variables). They are IDs, not passwords: OIDC needs no secret.

output "azure_client_id" {
  description = "GitHub variable AZURE_CLIENT_ID: which identity GitHub logs in as."
  value       = azurerm_user_assigned_identity.project.client_id
}

output "azure_tenant_id" {
  description = "GitHub variable AZURE_TENANT_ID."
  value       = azurerm_user_assigned_identity.project.tenant_id
}

output "azure_subscription_id" {
  description = "GitHub variable AZURE_SUBSCRIPTION_ID."
  value       = split("/", data.azurerm_machine_learning_workspace.department.id)[2]
}

output "workspace_name" {
  description = "GitHub variable AZUREML_WORKSPACE."
  value       = var.workspace_name
}

output "resource_group_name" {
  description = "GitHub variable AZUREML_RESOURCE_GROUP."
  value       = var.workspace_resource_group_name
}

output "compute_name" {
  description = "Compute cluster to use in jobs/*.yml."
  value       = azurerm_machine_learning_compute_cluster.project.name
}

output "principal_id" {
  description = "Object ID of the project identity: give this one access to the Fabric workspaces (see README)."
  value       = azurerm_user_assigned_identity.project.principal_id
}
