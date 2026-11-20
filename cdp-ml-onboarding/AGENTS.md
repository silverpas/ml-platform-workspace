# AGENTS.md: onboarding ML use cases in the platform (CDP) repo

Instructions for platform engineers who onboard a new ML use case, and for
their AI coding agents.

## What this repo is for

A **simulated slice of the platform repo (CDP)**. It shows exactly what gets
added there for ML: one workspace block per department, and one block per ML
use case. It is an **example**, not a replacement for the real platform repo.
Copy the pattern into the real repo; do not run it from here.

Jargon in one line each:
- **CDP repo**: the platform team's existing Terraform repo for the data platform.
- **Module block**: a few lines that call a reusable Terraform module with inputs.
- **`terraform plan`**: a dry run that lists what would be created or changed.
- **Outputs**: values Terraform prints after apply (here: IDs for GitHub variables).

## Where this repo sits in the overall process

| Step | What happens | This repo? |
|---|---|---|
| 0. Explore | Try the idea | No |
| 1. Request | Request form | No |
| 2. Qualify | Go → **add one `ml-project` block**, plan, review, apply | **Yes** |
| 3. Data and priority | Fill in `data_domains`; Fabric access | **Yes** |
| 4. Build | Hand the outputs to the project team | **Yes: hand-over** |
| 5. Run and review | Retire = remove the block | **Yes** |

## Folder structure (built in milestone 5)

```
ml/providers.tf         azurerm + azuread providers, pinned
ml/workspaces.tf        added ONCE: one ml-workspace block (manufacturing)
ml/projects.tf          one ml-project block per use case (example: tool-wear)
ml/outputs.tf           per-project outputs = the project repo's GitHub variables
onboarding-checklist.md step-by-step onboarding of a new use case
examples/onboard-new-use-case.diff   the exact diff for a second use case
```

In this example only, module `source` points to `../ml-infra-template/modules/...`
so it validates locally. In the real repo it points to wherever the platform
team keeps the modules.

## Workflow: onboard a new ML use case

1. Open a branch in the platform repo.
2. Add one `ml-project` block in `ml/projects.tf` and its outputs in `ml/outputs.tf`
   (copy `examples/onboard-new-use-case.diff`).
3. Open a pull request; run `terraform plan`.
4. Check the plan: only new resources for this use case; no Owner or
   Contributor roles; the federated credential names the right repo; nothing destroyed.
5. Review, merge, apply (platform team, in the real repo).
6. Hand over to the project team: set the outputs as GitHub variables
   `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`,
   `AZURE_RESOURCE_GROUP`, `AZURE_ML_WORKSPACE` in their repo.

Details: `onboarding-checklist.md` (milestone 5).

## Commands (no Azure account needed)

```bash
terraform -chdir=ml fmt -recursive
terraform -chdir=ml init -backend=false
terraform -chdir=ml validate
```

## Rules (what not to do)

- **Never run `terraform apply`** from here, never create cloud resources.
- **No secrets**, no real IDs, no client or internal system names.
- One block per use case; do not edit other use cases' blocks in the same PR.
- Never give a use case Owner or Contributor.
- Mark every guess about the real platform repo with `# ASSUMPTION:`.
- When you change this folder, update this file in the same change.
