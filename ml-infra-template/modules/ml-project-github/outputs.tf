# Values other code needs: ml-project (github_ids) and the people (repo URL).

output "github_ids" {
  description = "Numeric IDs of the owner and the repo, as used in the Azure login rules."
  value = {
    owner_id = local.owner_id
    repo_id  = local.repo_id
  }
}

output "oidc_subject_main" {
  description = "The subject the Azure login rule for the main branch expects."
  value       = azurerm_federated_identity_credential.github_main.subject
}

output "repo_url" {
  description = "Web address of the project repo."
  value       = "https://github.com/${var.github_repo}"
}

output "has_approval_gate" {
  description = "true when deploy.yml waits for a reviewer."
  value       = length(var.reviewer_user_ids) + length(var.reviewer_team_ids) > 0
}
