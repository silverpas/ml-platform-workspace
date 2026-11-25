# Terraform module: `ml-project-github`

Makes **one ML use case's GitHub repo ready to run**, with no manual steps.
Use it together with [`ml-project`](../ml-project/README.md), which prepares
the Azure side. The platform repo calls both once per registry YAML file.

## What it creates

| Resource | Why |
|---|---|
| The project repo, from the template (`create_repo = true`, private) | The use case's code, jobs and workflows. Or `create_repo = false` for an existing repo |
| Five GitHub variables: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `AZURE_RESOURCE_GROUP`, `AZURE_ML_WORKSPACE` | The workflows log in to Azure with them (IDs, not secrets) |
| Environment `production` (with `reviewer_user_ids` / `reviewer_team_ids`) | The approval gate of `deploy.yml` |
| 2 federated credentials on the project identity | GitHub may log in to Azure as the project, without secrets, only from this repo |

It also adds the two **Azure login rules** (federated credentials) to the
project identity. GitHub names the repo in its login with numeric IDs
(`repo:org@123/repo@456:...`); this module reads them from GitHub, so the rules
always match. Call `ml-project` with `create_github_login = false`.

Destroying the module **archives** the repo (read-only); it never deletes code.

## How the two modules connect

```hcl
module "tool_wear_github" {
  source        = "../ml-project-github"
  identity_id   = module.tool_wear.identity_id
  github_repo   = "example-org/ml-tool-wear"
  template_repo = "example-org/ml-project-template"
  azure = {
    client_id       = module.tool_wear.azure_client_id
    tenant_id       = module.tool_wear.azure_tenant_id
    subscription_id = module.tool_wear.azure_subscription_id
    resource_group  = module.tool_wear.resource_group_name
    workspace       = module.tool_wear.workspace_name
  }
}

module "tool_wear" {
  source      = "../ml-project"
  github_repo         = "example-org/ml-tool-wear"
  create_github_login = false
  # ... the other ml-project inputs
}
```

## Who can apply it

Terraform needs a GitHub login that may create repos and change their
settings: on a laptop `export GITHUB_TOKEN=$(gh auth token)`; in a platform
repo, usually a GitHub App of the organization. Required reviewers on a
**private** repo need a paid GitHub plan (Team or Enterprise for organizations).

## Test it locally (no GitHub needed)

```bash
terraform -chdir=modules/ml-project-github init -backend=false
terraform -chdir=modules/ml-project-github validate
terraform -chdir=modules/ml-project-github test
```
