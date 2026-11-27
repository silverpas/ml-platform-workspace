# Terraform module: `ml-project`

Plugs **one ML project** into its existing Azure ML workspace (by default the
project's own, in its own resource group).
The platform team adds one `module` block per use case in its own Terraform repo
(see [examples/basic/main.tf](examples/basic/main.tf)).

This module does **not** create the workspace. It comes from the
[`ml-workspace`](../ml-workspace/README.md) module, once per project. It
**does** create the project's own compute cluster.

## What it creates

| Resource | Why |
|---|---|
| User-assigned managed identity `id-ml-<department>-<name>` | The "robot account" the project's GitHub workflows and jobs run as |
| 2 federated credentials (GitHub OIDC), unless `create_github_login = false` | GitHub may log in as that identity **without any secret**, but only from this repo's `main` branch and its approval-gated environment. With `ml-project-github` (the usual setup) that module creates them instead, with the repo's numeric IDs |
| Compute cluster `cpu-<name>` (or `gpu-<name>`) | The project's own machines: run as the project identity (data access per project), tagged with `use_case` (costs per project), **scale to 0** when idle, at most `max_nodes` (default 1) |
| Role assignment *AzureML Data Scientist* on the workspace | Submit jobs and register models; cannot change the workspace or compute |
| Role assignment *AcrPull* on the workspace's container registry | The cluster loads the job environments with the project identity (the registry has no admin password) |
| *Optional:* Entra ID group `grp-ml-<department>-<name>` + the same role | Only with `create_team_group = true`; needs permission to create groups (often only IT) |

All resources are tagged with `department`, `use_case`, `owner` and `data_domains`
(and `environment`, if given). The `cluster` output (name, machine type, idle
minutes) goes to the project team: the name into `jobs/*.yml` (`compute:`),
the machine type into `config.yml` (`cost`). Cluster names have at most 16
characters; longer defaults are shortened with a 6-character suffix.

**Names from outside:** `names = { identity = "...", team_group = "...", cluster = "..." }`
replaces the default names; anything left out keeps its default. The optional
`environment` (off by default) must match the workspace's and adds
`-<environment>` to the default names.

## Inputs

| Name | Required | Example |
|---|---|---|
| `department` | yes | `manufacturing` |
| `name` | yes | `tool-wear` (3-24 characters; same as the model and repo) |
| `owner` | yes | `maintenance-analytics-team` |
| `github_repo` | yes | `example-org/ml-tool-wear` |
| `github_ids` | no (none) | `{ owner_id = 123, repo_id = 456 }`: only if GitHub's OIDC subject contains IDs (see below) |
| `workspace_name` | yes | the project's workspace |
| `lookup_workspace`, `workspace_id`, `location` | no (`true`, look up by name) | When ml-workspace runs in the same Terraform, set `lookup_workspace = false` and pass its `workspace_id` and `location` outputs: a change to the workspace then never forces Terraform to replace the identity and cluster |
| `workspace_resource_group_name` | yes | its resource group |
| `container_registry_id` | yes, unless `create_role_assignments = false` | ml-workspace output `container_registry_id` |
| `gpu` | no (`false`) | `true` = a GPU cluster (needs GPU quota from Microsoft first) |
| `vm_size`, `max_nodes`, `idle_minutes_before_scale_down` | no (`Standard_DS3_v2`, `1`, `15`) | the cluster; must fit the subscription's quota |
| `create_role_assignments` | no (`true`) | `false` when you may not assign roles (sandbox); see `roles_to_assign_by_hand` |
| `environment` | no (none) | `dev`, `prod`: only if the workspace has one |
| `names` | no (defaults) | `{ identity = "uai-mfg-toolwear-01" }` |
| `data_domains` | no (`[]`) | `["production"]`: recorded; access is granted in Fabric by hand |
| `create_team_group`, `team_member_object_ids` | no (`false`, `[]`) | optional team group |
| `deploy_environment`, `tags` | no | see [variables.tf](variables.tf) |

**Who can apply it:** the role assignments need Owner, User Access
Administrator or *Role Based Access Control Administrator* on the workspace's
resource group. Contributor is not enough: with only Contributor, set
`create_role_assignments = false` and ask for the roles in the
`roles_to_assign_by_hand` output.

## After `terraform apply` (done by the platform team)

1. **GitHub variables.** Set these in the project repo under
   *Settings → Secrets and variables → Actions → Variables*. They are IDs, not secrets:
   `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`,
   `AZURE_RESOURCE_GROUP`, `AZURE_ML_WORKSPACE` (from the module outputs).
2. **Fabric access (manual for now).** Fabric permissions are not managed by
   the `azurerm` provider. The `fabric_access_todo` output lists what to do. In
   Fabric, give the identity (`principal_id` output):
   - **Viewer** on the workspace that holds the input data;
   - **Contributor** on the workspace with the Gold lakehouse, where the
     predictions table (`ml_<use case>_predictions`) is written.

## If GitHub's login fails with "No matching federated identity record"

GitHub's OIDC subject can contain numeric IDs, e.g.
`repo:example-org@123/ml-tool-wear@456:ref:refs/heads/main`. The error message
shows the subject GitHub sent. If it has `@<number>` parts, set `github_ids`:

```bash
gh api repos/<org>/<repo> --jq '.owner.id, .id'   # owner_id, repo_id
```

## Test it locally (no Azure needed)

```bash
terraform -chdir=modules/ml-project init -backend=false
terraform -chdir=modules/ml-project validate
terraform -chdir=modules/ml-project test
```

`terraform test` uses a **mock provider**: a fake Azure that makes a plan and
checks what *would* be created. Nothing is created and no login is needed.
