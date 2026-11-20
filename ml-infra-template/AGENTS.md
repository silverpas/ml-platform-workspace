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
modules/ml-workspace/   ONCE per department (milestone 4):
                        Azure ML workspace + storage, key vault, Application
                        Insights, CPU cluster scaling to 0, optional GPU cluster
modules/ml-project/     ONCE per use case: identity for GitHub Actions, access to
                        the workspace, (milestone 4) Entra ID group, data access
                        placeholders. Outputs: the IDs for the project's GitHub variables
  examples/basic/       how to call the module
  tests/                terraform test with a fake (mock) Azure
```

`ml-project` is currently the first version (identity, role, compute cluster).
Milestone 4 rebuilds it with the inputs `department`, `name`, `owner`,
`github_repo`, `gpu`, `data_domains`, and adds `ml-workspace`.

## Workflow for users (platform engineers)

1. Once per department: add one `ml-workspace` block in the platform repo.
2. Per approved use case: add one `ml-project` block (see `examples/basic/`).
3. Open a pull request, run `terraform plan`, review it, then apply (in the platform repo, by the platform team).
4. Copy the outputs to the project repo's GitHub variables:
   `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`,
   `AZURE_RESOURCE_GROUP`, `AZURE_ML_WORKSPACE`.

A full worked example lives in the `cdp-ml-onboarding` folder/repo.

## Commands (no Azure account needed)

```bash
terraform -chdir=modules/ml-project fmt -recursive
terraform -chdir=modules/ml-project init -backend=false
terraform -chdir=modules/ml-project validate
terraform -chdir=modules/ml-project test     # mock provider: nothing is created
```

## Rules (what not to do)

- **Never run `terraform apply`** from this repo, and never create cloud resources.
  Only `fmt`, `init -backend=false`, `validate` and `test` (mock provider).
- **No secrets**, no real subscription, tenant or resource IDs, no client names.
- **Least privilege**: never give use-case identities or groups Owner or Contributor.
- **Federated credentials trust only `repo:<github_repo>`** (its `main` branch
  and its approval environment), never a whole organization.
- **Pin provider versions** (`azurerm`, `azuread`).
- Mark every guess about the platform team's setup with `# ASSUMPTION:`.
- Examples use department `manufacturing` and use case `tool-wear`.
- When you change a module, update its README, its tests and this file in the same change.
