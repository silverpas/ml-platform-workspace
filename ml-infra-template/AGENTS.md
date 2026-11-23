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
- **Azure ML workspace**: the place in Azure where ML experiments, models and compute live.
- **Workload identity + federated credential**: a "robot account" that GitHub
  Actions can log in as via OIDC, with no stored password.
- **Entra ID group**: a group of people (formerly Azure AD) that gets permissions together.
- **Mock provider**: a fake Azure used by `terraform test`; nothing is created.
- **Resource group**: a folder in Azure for resources that are created and deleted together.

## Where this repo sits in the overall process

| Step | What happens | This repo? |
|---|---|---|
| 0. Explore | Try the idea | No |
| 1. Request | Request form | No |
| 2. Qualify | Go → one `ml-project` block is added in the CDP repo | **Yes: the module used** |
| 3. Data and priority | Data access (`data_domains`) | **Yes: placeholders** |
| 4. Build | The project repo trains in the workspace | Uses what was created |
| 5. Run and review | Scoring writes to the predictions lakehouse | Uses what was created |

## Folder structure

```
modules/ml-workspace/   ONCE per department, in an EXISTING resource group:
                        Azure ML workspace + storage, key vault, Application
                        Insights, container registry, shared `cpu-cluster`
                        scaling to 0, optional `gpu-cluster`
modules/ml-project/     ONCE per use case: identity for GitHub Actions (OIDC),
                        AzureML Data Scientist role on the workspace, optional
                        Entra ID team group, data domains (placeholders).
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
- **Clusters scale to 0** (`min_node_count = 0`); never add compute instances.
- **Modules never create resource groups**: they receive one as input.
- Mark every guess about the platform team's setup with `# ASSUMPTION:`.
- Examples use department `manufacturing` and use case `tool-wear`.
- When you change a module, update its README, its tests and this file in the same change.
