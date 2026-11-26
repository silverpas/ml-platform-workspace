# What the platform team hands over after apply.

output "registry_checks" {
  description = "Rules that connect registry files. The plan stops if any is broken."
  value       = "ok: ${length(local.use_cases)} active ML project(s)"

  precondition {
    condition     = length(local.problems) == 0
    error_message = "The ML registry is inconsistent:\n- ${join("\n- ", local.problems)}"
  }
}

output "project_resource_groups" {
  description = "Per use case: its resource group (all its Azure resources are inside)."
  value       = { for key, rg in local.resource_groups : key => rg.name }
}

output "project_repos" {
  description = "Per use case: its GitHub repo, ready to run (only with manage_github = true)."
  value       = { for key, gh in module.ml_project_github : key => gh.repo_url }
}

output "github_variables" {
  description = "Per use case: the five GitHub variables. Set automatically with manage_github = true; otherwise set them by hand (Settings -> Secrets and variables -> Actions -> Variables)."
  value = {
    for key, project in module.ml_project : local.use_cases[key].github_repo => {
      AZURE_CLIENT_ID       = project.azure_client_id
      AZURE_TENANT_ID       = project.azure_tenant_id
      AZURE_SUBSCRIPTION_ID = project.azure_subscription_id
      AZURE_RESOURCE_GROUP  = project.resource_group_name
      AZURE_ML_WORKSPACE    = project.workspace_name
    }
  }
}

output "project_clusters" {
  description = "Per use case: its own cluster. The name goes into the project's jobs/*.yml (compute), the machine type into config.yml (cost)."
  value = {
    for key, project in module.ml_project : local.use_cases[key].github_repo => project.cluster
  }
}

output "data_access_todo" {
  description = "Per use case: what the data owners still grant in Fabric (read access, predictions table)."
  value = {
    for key, project in module.ml_project : key => merge(project.fabric_access_todo, {
      read_tables       = local.use_cases[key].reads
      predictions_table = local.use_cases[key].predictions_table
      compute           = project.compute_name
    })
  }
}
