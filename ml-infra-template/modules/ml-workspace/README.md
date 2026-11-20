# Terraform module: `ml-workspace`

Creates **one Azure ML workspace for a department**, with everything it needs.
The platform team adds one `module` block per department in its own Terraform
repo (see [examples/basic/main.tf](examples/basic/main.tf)). Use cases then plug
in with the [`ml-project`](../ml-project/README.md) module.

The resource group must already exist: the module creates everything **inside**
it, so it fits however the platform team organizes resource groups, and
`terraform destroy` removes only what this module created.

## What it creates

| Resource | Name | Why |
|---|---|---|
| Azure ML workspace | `mlw-<department>` | Experiments, model registry, jobs |
| Storage account | `stml<department><6 chars>` | The workspace's files: data, models, logs |
| Key vault | `kv-ml-<department>-<6 chars>` | The workspace's own keys and passwords |
| Log Analytics + Application Insights | `log-mlw-…`, `appi-mlw-…` | Monitoring logs |
| Container registry (Basic) | `crml<department><6 chars>` | Python environments of the jobs, built once and reused |
| CPU cluster | `cpu-cluster` | Shared by all use cases; **scales to 0** machines when idle |
| GPU cluster (optional) | `gpu-cluster` | Only with `gpu = true`; max 1 machine, scales to 0 |

The `<6 chars>` come from the resource group's ID: storage, key vault and
registry names must be unique in all of Azure.

## Costs (rough, check the Azure pricing calculator)

- **Fixed while it exists:** about 5 EUR per month for the container registry,
  plus a few cents for storage, key vault and logs.
- **Only when used:** the clusters, per minute while a job runs. Idle machines
  are switched off after 15 minutes (`idle_minutes_before_scale_down`).
- Never create a *compute instance* (a personal VM for notebooks) without
  auto-shutdown: it costs every hour it is on.

## Inputs

| Name | Required | Example |
|---|---|---|
| `department` | yes | `manufacturing` |
| `resource_group_name` | yes | an existing resource group |
| `owner` | yes | `ml-platform-team` |
| `gpu` | no (`false`) | `true` needs GPU quota from Microsoft first |
| `cpu_cluster_name`, `cpu_vm_size`, `cpu_max_nodes`, `gpu_vm_size`, `idle_minutes_before_scale_down`, `public_network_access`, `tags` | no | see [variables.tf](variables.tf) |

## Who can apply it

Creating the workspace needs the **Contributor** role on the resource group.
Assigning roles (done by `ml-project`) needs more (Owner, User Access
Administrator or Role Based Access Control Administrator).

## Test it locally (no Azure needed)

```bash
terraform -chdir=modules/ml-workspace init -backend=false
terraform -chdir=modules/ml-workspace validate
terraform -chdir=modules/ml-workspace test
```

`terraform test` uses a **mock provider**: a fake Azure that makes a plan and
checks what *would* be created. Nothing is created and no login is needed.
