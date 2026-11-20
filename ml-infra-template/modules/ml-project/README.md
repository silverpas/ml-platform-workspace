# Terraform module: `ml-project`

Plugs **one ML use case** into its department's existing Azure ML workspace.
The platform team adds one `module` block per use case in its own Terraform repo
(see [examples/basic/main.tf](examples/basic/main.tf)).

This module does **not** create the workspace. The platform team creates one
Azure ML workspace per department, once.

## What it creates

| Resource | Why |
|---|---|
| User-assigned managed identity `id-ml-<department>-<name>` | The "robot account" the project's GitHub workflows and jobs run as |
| 2 federated credentials (GitHub OIDC) | GitHub may log in as that identity **without any secret**, but only from this repo's `main` branch and its approval-gated environment |
| Role assignment *AzureML Data Scientist* on the workspace | Submit jobs and register models; cannot change the workspace or compute |
| Compute cluster `cc-<name>` | CPU by default, GPU with `gpu = true`; scales to 0 machines when idle |

All resources are tagged with `department`, `use_case` and `owner`.

## Inputs

| Name | Required | Example |
|---|---|---|
| `department` | yes | `manufacturing` |
| `name` | yes | `machine-fail` (max 13 characters) |
| `owner` | yes | `maintenance-analytics-team` |
| `github_repo` | yes | `example-org/ml-machine-failure` |
| `workspace_name` | yes | the department workspace |
| `workspace_resource_group_name` | yes | its resource group |
| `gpu` | no (`false`) | `true` needs GPU quota from Microsoft first |
| `max_nodes`, `cpu_vm_size`, `gpu_vm_size`, `deploy_environment`, `tags` | no | see [variables.tf](variables.tf) |

## After `terraform apply` (done by the platform team)

1. **GitHub variables.** Set these in the project repo under
   *Settings → Secrets and variables → Actions → Variables*. They are IDs, not secrets:
   `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`,
   `AZURE_RESOURCE_GROUP`, `AZURE_ML_WORKSPACE` (from the module outputs).
2. **Fabric access (manual for now).** Fabric permissions are not managed by
   the `azurerm` provider. In Fabric, give the identity (`principal_id` output):
   - **Viewer** on the workspace that holds the input data;
   - **Contributor** on the workspace with the predictions lakehouse.

## Test it locally (no Azure needed)

```bash
terraform -chdir=modules/ml-project init -backend=false
terraform -chdir=modules/ml-project validate
terraform -chdir=modules/ml-project test
```

`terraform test` uses a **mock provider**: a fake Azure that makes a plan and
checks what *would* be created. Nothing is created and no login is needed.
