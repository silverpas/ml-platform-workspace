# Terraform module: `ml-workspace`

Creates **one Azure ML workspace** with everything it needs. The default
setup is **one workspace per ML project**, in the project's own resource group,
so projects are fully separated. The
platform's registry Terraform calls it once per project (or see
[examples/basic/main.tf](examples/basic/main.tf) for a direct call). The
project then plugs in with the [`ml-project`](../ml-project/README.md) module.

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

**No compute.** Each use case gets its **own cluster** from `ml-project`, with
the project's identity and tags, so data access and costs are per project. Pass
the `container_registry_id` output to `ml-project`.

The `<6 chars>` come from the resource group's ID (and the environment, if
any): storage, key vault and registry names must be unique in all of Azure.

## Your own names and an optional environment

The names above are **defaults**. If the platform has naming rules (often
defined in one central place), pass the names in: anything left out keeps its
default.

```hcl
names = {
  workspace       = "mlw-mfg-weu-01"
  storage_account = "stmlmfgweu01" # 3-24 lowercase letters/digits, no hyphens
}
```

`environment` (e.g. `dev`, `prod`) is **optional and off by default**. The
recommended setup is one workspace per project, without environments: the approval gate
(candidate → champion) already keeps untested models away from real
predictions. Set it only if the platform's rules require separate
environments; it adds `-<environment>` to the default names and an
`environment` tag, so each environment gets its own workspace.

## Costs (rough, check the Azure pricing calculator)

- **Fixed while it exists:** about 5 EUR per month for the container registry,
  plus a few cents for storage, key vault and logs.
- **Only when used:** the projects' clusters (see `ml-project`), per minute
  while a machine is on.
- Never create a *compute instance* (a personal VM for notebooks) without
  auto-shutdown: it costs every hour it is on.

## Inputs

| Name | Required | Example |
|---|---|---|
| `department` | yes | `manufacturing` |
| `resource_group_name` | yes | the project's resource group (`rg-ml-<department>-<use case>`) |
| `owner` | yes | `ml-platform-team` |
| `environment` | no (none) | `dev`, `prod`: only if the platform requires environments |
| `names` | no (defaults) | your own names, see above |
| `public_network_access`, `tags` | no | see [variables.tf](variables.tf) |

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
