# Terraform module: `ml-project`

Plugs **one ML use case** into its department's existing Azure ML workspace.
The platform team adds one `module` block per use case in its own Terraform repo
(see [examples/basic/main.tf](examples/basic/main.tf)).

This module does **not** create the workspace or compute clusters. They come
from the [`ml-workspace`](../ml-workspace/README.md) module, once per department.

## What it creates

| Resource | Why |
|---|---|
| User-assigned managed identity `id-ml-<department>-<name>` | The "robot account" the project's GitHub workflows and jobs run as |
| 2 federated credentials (GitHub OIDC) | GitHub may log in as that identity **without any secret**, but only from this repo's `main` branch and its approval-gated environment |
| Role assignment *AzureML Data Scientist* on the workspace | Submit jobs and register models; cannot change the workspace or compute |
| *Optional:* Entra ID group `grp-ml-<department>-<name>` + the same role | Only with `create_team_group = true`; needs permission to create groups (often only IT) |

All resources are tagged with `department`, `use_case`, `owner` and `data_domains`.
The project uses the department's shared `cpu-cluster` (or `gpu-cluster` with
`gpu = true`); the `compute_name` output says which.

## Inputs

| Name | Required | Example |
|---|---|---|
| `department` | yes | `manufacturing` |
| `name` | yes | `tool-wear` (3-24 characters; same as the model and repo) |
| `owner` | yes | `maintenance-analytics-team` |
| `github_repo` | yes | `example-org/ml-tool-wear` |
| `workspace_name` | yes | the department workspace |
| `workspace_resource_group_name` | yes | its resource group |
| `gpu` | no (`false`) | `true` = use the shared GPU cluster (ml-workspace with `gpu = true`) |
| `data_domains` | no (`[]`) | `["production"]`: recorded; access is granted in Fabric by hand |
| `create_team_group`, `team_member_object_ids` | no (`false`, `[]`) | optional team group |
| `deploy_environment`, `tags` | no | see [variables.tf](variables.tf) |

**Who can apply it:** the role assignments need Owner, User Access
Administrator or *Role Based Access Control Administrator* on the workspace's
resource group. Contributor is not enough.

## After `terraform apply` (done by the platform team)

1. **GitHub variables.** Set these in the project repo under
   *Settings → Secrets and variables → Actions → Variables*. They are IDs, not secrets:
   `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`,
   `AZURE_RESOURCE_GROUP`, `AZURE_ML_WORKSPACE` (from the module outputs).
2. **Fabric access (manual for now).** Fabric permissions are not managed by
   the `azurerm` provider. The `fabric_access_todo` output lists what to do. In
   Fabric, give the identity (`principal_id` output):
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
