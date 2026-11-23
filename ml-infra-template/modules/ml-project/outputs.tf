# Values the platform team hands to the project team after `terraform apply`.
# The first five go into the GitHub repo as *variables* (Settings -> Secrets and
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
  description = "GitHub variable AZURE_ML_WORKSPACE."
  value       = var.workspace_name
}

output "resource_group_name" {
  description = "GitHub variable AZURE_RESOURCE_GROUP."
  value       = var.workspace_resource_group_name
}

output "compute_name" {
  description = "Shared cluster to use in the project's jobs/*.yml (compute: azureml:<name>), from ml-workspace."
  value       = coalesce(var.compute_name, var.gpu ? "gpu-cluster" : "cpu-cluster")
}

output "team_group_id" {
  description = "Object ID of the team's Entra ID group, or null when create_team_group = false."
  value       = var.create_team_group ? azuread_group.team[0].object_id : null
}

output "fabric_access_todo" {
  description = "What the platform team must still grant by hand in Fabric (not managed by Terraform yet)."
  value = {
    identity_principal_id = azurerm_user_assigned_identity.project.principal_id
    read_data_domains     = var.data_domains
    # ASSUMPTION: the predictions go to a Gold ml_ table in the department's
    # Fabric workspace; writing needs Contributor there.
    write_predictions = "Contributor on the ${var.department} Fabric workspace with the Gold lakehouse (ml_ predictions table)"
  }
}

output "principal_id" {
  description = "Object ID of the project identity: give this one access to the Fabric workspaces (see README)."
  value       = azurerm_user_assigned_identity.project.principal_id
}
