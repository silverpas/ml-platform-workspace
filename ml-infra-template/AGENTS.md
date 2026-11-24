# AGENTS.md: ML infrastructure template

Instructions for platform engineers who use these Terraform modules, and for
their AI coding agents.

## What this repo is for

Reusable **Terraform modules** that create the Azure infrastructure for ML.
They are a **proposal to the platform team**: the platform team copies or
references them from its own platform repo (CDP) and runs them there. This
repo never runs `terraform apply` itself.

Jargon in one line each:
- **Terraform module**: a reusable recipe of Azure resources; you call it with a few inputs.
- **Azure ML workspace**: the place in Azure where ML experiments and models live.
- **Compute cluster**: cloud machines that run the jobs; it starts machines when a
  job arrives and switches them off (scales to 0) when idle.
- **Workload identity + federated credential**: a "robot account" that GitHub
  Actions can log in as via OIDC, with no stored password.
- **Entra ID group**: a group of people (formerly Azure AD) that gets permissions together.
- **Mock provider**: a fake Azure used by `terraform test`; nothing is created.
- **Resource group**: a folder in Azure for resources that are created and deleted together.
- **Environment** (dev/test/prod): separate copies of the setup; optional here, off by default.

## Where this repo sits in the overall process

| Step | What happens | This repo? |
|---|---|---|
| 0. Explore | Try the idea on a laptop | No |
| 1. Request | Request form | No |
| 2. Qualify | Go / not now / no | No |
| 3. Data and priority | Data access (`data_domains`); at the end: one registry YAML in the platform repo → one `ml-project` | **Yes: the module used; data access as placeholders** |
| 4. Build | The project repo trains in the workspace | Uses what was created |
| 5. Run and review | Scoring writes to a Gold `ml_` table in Fabric | Uses what was created |

## Folder structure

```
modules/ml-workspace/   ONCE per department, in an EXISTING resource group:
                        Azure ML workspace + storage, key vault, Application
                        Insights, container registry. No compute.
modules/ml-project/     ONCE per use case: identity for GitHub Actions (OIDC)
                        and jobs, the project's OWN cluster (CPU or GPU, scales
                        to 0, tagged per project, runs as that identity),
                        AzureML Data Scientist + AcrPull roles, optional Entra
                        ID team group, data domains (placeholders).
                        Outputs: the IDs for the project's GitHub variables
modules/*/examples/basic/   how to call each module
modules/*/tests/            terraform test with a fake (mock) Azure
```

Both modules: `versions.tf` (pinned providers), `variables.tf` (inputs),
`main.tf` (resources), `outputs.tf` (results), `README.md`.

## Workflow for users (platform engineers)

The modules are the engine behind a **metadata-driven** registry: people add
YAML files, and the platform repo's Terraform calls the modules once per file
(worked example: the `cdp-ml-onboarding` folder/repo).

1. Once per department: `registry/ml_workspaces/<department>.yaml` → one
   `ml-workspace` (needs Contributor on the resource group).
2. Per approved use case: `registry/ml_use_cases/<department>__<id>.yaml` → one
   `ml-project` (see also `examples/basic/` for a direct call).
3. Open a pull request, run `terraform plan`, review it, then apply (in the
   platform repo, by the platform team). `ml-project` assigns roles, so it needs
   Owner, User Access Administrator or Role Based Access Control Administrator.
4. Copy the outputs to the project repo's GitHub variables:
   `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`,
   `AZURE_RESOURCE_GROUP`, `AZURE_ML_WORKSPACE`.

**Fitting the platform's rules.** Every name has a default (`mlw-<department>`,
`id-ml-<department>-<use case>`, ...). If the platform has naming rules, pass
the names in with `names = { ... }` (for `ml-project` also `cluster`);
anything left out keeps its default. `environment` is optional and off by
default: one workspace per department is the recommended setup, because the
approval gate already separates tested from untested models.

## Commands (no Azure account needed)

For each module (`ml-workspace`, `ml-project`):

```bash
terraform -chdir=modules/ml-workspace fmt -recursive
terraform -chdir=modules/ml-workspace init -backend=false
terraform -chdir=modules/ml-workspace validate
terraform -chdir=modules/ml-workspace test     # mock provider: nothing is created
```

## Rules (what not to do)

- **Never run `terraform apply`** from this repo, and never create cloud resources.
  Only `fmt`, `init -backend=false`, `validate` and `test` (mock provider).
- **No secrets**, no real subscription, tenant or resource IDs, no client names.
- **Least privilege**: never give use-case identities or groups Owner or Contributor.
- **Federated credentials trust only `repo:<github_repo>`** (its `main` branch
  and its approval environment), never a whole organization.
- **Pin provider versions** (`azurerm ~> 4.81`, `azuread ~> 3.10`); the same in both modules and examples.
- **One cluster per use case, in `ml-project`**, running as the project's identity
  and tagged with `use_case` (data access and costs per project). Clusters scale
  to 0 (`min_node_count = 0`); never add compute instances.
- **No role-assignment right** (e.g. a personal sandbox): `create_role_assignments
  = false`; the `roles_to_assign_by_hand` output lists what someone else must do.
- **Modules never create resource groups**: they receive one as input.
- **Defaults never change silently**: without `environment` and `names`, names stay
  exactly as they are (a rename means Azure deletes and recreates the resource).
- Mark every guess about the platform team's setup with `# ASSUMPTION:`.
- Examples use department `manufacturing` and use case `tool-wear`.
- When you change a module, update its README, its tests and this file in the same change.
