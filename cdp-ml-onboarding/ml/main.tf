# Metadata-driven ML onboarding: Terraform reads the ML registry (YAML files)
# and calls the shared modules once per file. Nobody writes a module block per
# department or per use case; they add a YAML file in a pull request.
#
#   registry/ml_workspaces/<department>.yaml             -> module.ml_workspace["<department>"]
#   registry/ml_use_cases/<department>__<use_case>.yaml  -> module.ml_project["<department>__<use_case>"]
#
# The YAML files are checked against registry/schema/*.schema.json in the pull
# request (tests/test_registry.py). The checks below repeat the rules that
# connect two files, so a plan never runs on an inconsistent registry.

locals {
  registry_dir = coalesce(var.registry_dir, "${path.module}/../registry")

  # One entry per file; the key is the file name without .yaml.
  workspaces = {
    for f in fileset("${local.registry_dir}/ml_workspaces", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(file("${local.registry_dir}/ml_workspaces/${f}"))
  }
  all_use_cases = {
    for f in fileset("${local.registry_dir}/ml_use_cases", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(file("${local.registry_dir}/ml_use_cases/${f}"))
  }

  # Retired use cases stay in the registry for the record, but get nothing:
  # removing them from this map makes Terraform delete their identity and access.
  active_use_cases = {
    for key, uc in local.all_use_cases : key => uc if lookup(uc, "status", "active") == "active"
  }

  # Rules that connect files. Anything listed here stops the plan (see outputs.tf).
  problems = concat(
    [for key, ws in local.workspaces : "ml_workspaces/${key}.yaml: department must be \"${key}\" (the file name)" if ws.department != key],
    [for key, uc in local.all_use_cases : "ml_use_cases/${key}.yaml: file name must be ${uc.department}__${uc.use_case_id}.yaml" if key != "${uc.department}__${uc.use_case_id}"],
    [for key, uc in local.active_use_cases : "ml_use_cases/${key}.yaml: no ml_workspaces/${uc.department}.yaml (turn on ML for the department first)" if !contains(keys(local.workspaces), uc.department)],
    [for key, uc in local.active_use_cases : "ml_use_cases/${key}.yaml: gpu: true, but ml_workspaces/${uc.department}.yaml has no GPU cluster" if lookup(uc, "gpu", false) && !lookup(lookup(local.workspaces, uc.department, {}), "gpu", false)],
  )

  # Only use cases whose department has a workspace are planned; the others are
  # reported in `problems` instead of failing with a confusing error.
  use_cases = {
    for key, uc in local.active_use_cases : key => uc if contains(keys(local.workspaces), uc.department)
  }
}

# Once per department with ML turned on.
module "ml_workspace" {
  source   = "../../ml-infra-template/modules/ml-workspace" # ASSUMPTION: in the real repo, wherever the platform keeps modules
  for_each = local.workspaces

  department          = each.value.department
  resource_group_name = each.value.resource_group
  owner               = each.value.owner
  gpu                 = lookup(each.value, "gpu", false)
  cpu_max_nodes       = lookup(each.value, "cpu_max_nodes", 2)
}

# Once per active ML use case.
module "ml_project" {
  source   = "../../ml-infra-template/modules/ml-project"
  for_each = local.use_cases

  department                    = each.value.department
  name                          = each.value.use_case_id
  owner                         = each.value.owner
  github_repo                   = each.value.github_repo
  gpu                           = lookup(each.value, "gpu", false)
  workspace_name                = module.ml_workspace[each.value.department].workspace_name
  workspace_resource_group_name = module.ml_workspace[each.value.department].resource_group_name

  # "manufacturing.gold.fact_machine_sensors" -> data domain "manufacturing"
  data_domains = distinct([for table in each.value.reads : split(".", table)[0]])

  tags = {
    risk_tier         = each.value.risk_tier
    predictions_table = each.value.predictions_table
  }

  # A department's first use case is often added together with its workspace:
  # wait until the workspace exists before looking it up.
  depends_on = [module.ml_workspace]
}
