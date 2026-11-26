# Metadata-driven ML onboarding: Terraform reads the ML registry (one YAML file
# per ML project) and builds everything the project needs. Nobody writes a
# module block per project; they add a YAML file in a pull request.
#
#   registry/ml_use_cases/<department>__<use_case>.yaml
#     -> resource group  rg-ml-<department>-<use_case>
#     -> module.ml_workspace       the project's own Azure ML workspace
#     -> module.ml_project         its identity, cluster and roles
#     -> module.ml_project_github  its GitHub repo, variables, approval gate, login
#
# One resource group and workspace per project: see
# docs/decisions/0001-one-resource-group-per-ml-project.md (workspace repo).
# The YAML files are checked against registry/schema/ml_use_case.schema.json in
# the pull request (tests/test_registry.py). The checks below repeat the rules
# that connect files, so a plan never runs on an inconsistent registry.

locals {
  registry_dir = coalesce(var.registry_dir, "${path.module}/../registry")

  # One entry per file; the key is the file name without .yaml.
  all_use_cases = {
    for f in fileset("${local.registry_dir}/ml_use_cases", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(file("${local.registry_dir}/ml_use_cases/${f}"))
  }

  # Retired use cases stay in the registry for the record, but get nothing:
  # removing them from this map makes Terraform delete their resources.
  use_cases = {
    for key, uc in local.all_use_cases : key => uc if lookup(uc, "status", "active") == "active"
  }

  # Per project: its own resource group, rg-ml-<department>-<use_case>, created
  # here. (existing_resource_groups is for tests in a group that already exists.)
  resource_groups = {
    for key, uc in local.use_cases : key => {
      name     = lookup(var.existing_resource_groups, key, "rg-ml-${uc.department}-${uc.use_case_id}")
      existing = contains(keys(var.existing_resource_groups), key)
      location = lookup(uc, "location", var.default_location)
    }
  }

  # Rules that connect files. Anything listed here stops the plan (see outputs.tf).
  problems = concat(
    [for key, uc in local.all_use_cases : "ml_use_cases/${key}.yaml: file name must be ${uc.department}__${uc.use_case_id}.yaml" if key != "${uc.department}__${uc.use_case_id}"],
    [for key, uc in local.use_cases : "ml_use_cases/${key}.yaml: github_repo must belong to ${var.github_owner}" if var.manage_github && split("/", uc.github_repo)[0] != var.github_owner],
    [for name in distinct([for rg in values(local.resource_groups) : rg.name]) : "resource group ${name} is used by more than one project (each project needs its own)" if length([for rg in values(local.resource_groups) : rg if rg.name == name]) > 1],
  )
}

# 1. The project's own resource group.
resource "azurerm_resource_group" "project" {
  for_each = { for key, rg in local.resource_groups : key => rg if !rg.existing }

  name     = each.value.name
  location = each.value.location
  tags = merge(var.extra_tags, {
    department = local.use_cases[each.key].department
    use_case   = local.use_cases[each.key].use_case_id
    owner      = local.use_cases[each.key].owner
    managed_by = "terraform"
  })
}

# 2. The project's own Azure ML workspace, in its resource group.
module "ml_workspace" {
  source   = "../../ml-infra-template/modules/ml-workspace" # ASSUMPTION: in the real repo, wherever the platform keeps modules
  for_each = local.use_cases

  department = each.value.department
  # A created group is referenced through the resource, so Terraform creates it first.
  resource_group_name = local.resource_groups[each.key].existing ? local.resource_groups[each.key].name : azurerm_resource_group.project[each.key].name
  owner               = each.value.owner

  # Names per project. The file may set its own (platform naming rules, or an
  # existing workspace); storage, key vault and registry get unique defaults.
  names = merge({
    workspace     = "mlw-${each.value.department}-${each.value.use_case_id}"
    log_analytics = "log-mlw-${each.value.department}-${each.value.use_case_id}"
    app_insights  = "appi-mlw-${each.value.department}-${each.value.use_case_id}"
  }, lookup(each.value, "names", {}))

  tags = merge(var.extra_tags, { use_case = each.value.use_case_id })
}

# 3. The project's identity, cluster and roles, in its workspace.
module "ml_project" {
  source   = "../../ml-infra-template/modules/ml-project"
  for_each = local.use_cases

  department  = each.value.department
  name        = each.value.use_case_id
  owner       = each.value.owner
  github_repo = each.value.github_repo
  # With manage_github, ml-project-github creates the GitHub login rules (it
  # reads the repo's numeric IDs itself). Otherwise ml-project does, with the
  # IDs from the file if GitHub's subject contains them.
  create_github_login           = !var.manage_github
  github_ids                    = var.manage_github ? null : lookup(each.value, "github_ids", null)
  gpu                           = lookup(each.value, "gpu", false) # the project's own cluster: CPU or GPU
  lookup_workspace              = false                            # ID and region come from ml_workspace directly
  workspace_id                  = module.ml_workspace[each.key].workspace_id
  location                      = module.ml_workspace[each.key].location
  container_registry_id         = module.ml_workspace[each.key].container_registry_id
  workspace_name                = module.ml_workspace[each.key].workspace_name
  workspace_resource_group_name = module.ml_workspace[each.key].resource_group_name

  # "manufacturing.gold.fact_machine_sensors" -> data domain "manufacturing"
  data_domains = distinct([for table in each.value.reads : split(".", table)[0]])

  create_role_assignments = var.create_role_assignments

  tags = merge(var.extra_tags, {
    risk_tier         = each.value.risk_tier
    predictions_table = each.value.predictions_table
  })

}

# 4. The GitHub side: the repo (from the template), its five Azure variables,
# its approval-gated environment and login rules. Skipped when manage_github = false.
module "ml_project_github" {
  source   = "../../ml-infra-template/modules/ml-project-github" # ASSUMPTION: as above
  for_each = var.manage_github ? local.use_cases : {}

  identity_id       = module.ml_project[each.key].identity_id
  github_repo       = each.value.github_repo
  template_repo     = var.template_repo
  create_repo       = lookup(each.value, "github_create_repo", true)
  description       = "${lookup(each.value, "display_name", each.value.use_case_id)} (ML use case, owner: ${each.value.owner})"
  reviewer_user_ids = lookup(each.value, "reviewer_github_ids", [])
  azure = {
    client_id       = module.ml_project[each.key].azure_client_id
    tenant_id       = module.ml_project[each.key].azure_tenant_id
    subscription_id = module.ml_project[each.key].azure_subscription_id
    resource_group  = module.ml_project[each.key].resource_group_name
    workspace       = module.ml_project[each.key].workspace_name
  }
}
