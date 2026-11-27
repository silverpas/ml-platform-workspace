# AGENTS.md: ML registry for the platform repo

Instructions for platform engineers who onboard ML use cases, and for their
AI coding agents.

## What this repo is for

An **example of the platform repo's ML registry**. Onboarding is
**metadata-driven**: a new ML project is one YAML file in a pull request.
Terraform reads every file and, per file, creates the project's own resource
group and calls the shared modules from `ml-infra-template` (workspace,
identity and cluster, GitHub repo). Nobody writes Terraform per project.

It is an **example**: copy the pattern into the real platform repo; do not
apply it from here. If the platform already has a registry with a resolver
(YAML → contract → Terraform), these files become a new object type there.

Jargon in one line each:
- **Registry**: a folder of YAML files that describe what should exist.
- **JSON schema**: a file with the rules a YAML file must follow (fields, formats).
- **Metadata-driven**: you describe *what* you want in a file; code does the *how*.
- **`terraform plan`**: a dry run that lists what would be created or changed.
- **Outputs**: values Terraform prints after apply (here: each project's resource group, repo link, cluster).

## Where this repo sits in the overall process

| Step | What happens | This repo? |
|---|---|---|
| 0. Explore | Try the idea on a laptop | No |
| 1. Request | Request form (ml-requests repo; same field names as the YAML) | No |
| 2. Qualify | Go / not now / no | No (ml-requests repo) |
| 3. Data and priority | Data and priority clear → **add one use case YAML**: the project's resource group, workspace, identity, cluster and GitHub repo; `reads` and `predictions_table`, access granted in Fabric | **Yes** |
| 4. Build | Hand the `github_variables` output to the project team | **Yes: hand-over** |
| 5. Run and review | Retire = `status: retired` | **Yes** |

## Folder structure

```
registry/
  ml_use_cases/<department>__<use_case>.yaml    ONE per ML project
  schema/ml_use_case.schema.json                rules for these files
ml/                     Terraform: reads the registry, calls the modules
  main.tf               per file: resource group + the three modules; cross-file checks
  outputs.tf            registry_checks, project_resource_groups, project_repos,
                        github_variables, project_clusters, data_access_todo
  variables.tf          registry_dir (tests), default_location, manage_github, github_owner, template_repo;
                        for tests/sandboxes: existing_resource_groups, create_role_assignments,
                        extra_tags, provider settings
  versions.tf           pinned providers (azurerm ~> 4.81, azuread ~> 3.10, github ~> 6.13)
  tests/                terraform test with a fake Azure and GitHub; tests/fixtures/ = small
                        test registries (good and broken)
tests/                  pytest: schema and cross-file checks
  invalid/              broken YAML examples the schema must refuse
docs/onboarding-checklist.md   step by step, for a person
requirements.txt        jsonschema, pyyaml, pytest (tests only)
```

In this example only, module `source` points to `../../ml-infra-template/modules/...`
so it validates locally. In the real repo it points to wherever the platform
team keeps the modules. Per project, `ml/main.tf` creates the project's own
resource group, then calls `ml_workspace` (the
project's own workspace; names `mlw-<department>-<use_case>` unless the file
sets `names`), `ml_project` (identity, own cluster, roles) and, with
`manage_github = true` (default), `ml_project_github` (repo from the template,
five Azure variables, `production` environment with `reviewer_github_ids`,
GitHub login rules). One YAML file is all a new project needs.

## Workflow: onboard a new ML use case

Follow [docs/onboarding-checklist.md](docs/onboarding-checklist.md). In short:

1. Add `registry/ml_use_cases/<department>__<use_case_id>.yaml`.
2. Optional in the file: `location` (region), `names` (naming rules).
3. Open a pull request: schema checks and `terraform plan` run.
4. Check the plan: only this project's resource group, workspace (with storage,
   key vault, registry, logs), identity, cluster, roles, repo, five GitHub
   variables, environment and two login rules; nothing destroyed.
5. Review, merge, apply (platform team, after approval, in the real repo).
6. Grant data access in Fabric (`data_access_todo` output) and give the team
   the repo link (`project_repos` output): it is ready to run.

## Commands (no Azure account needed)

```bash
pip install -r requirements.txt      # Python 3.11
pytest                               # schema and cross-file checks
terraform -chdir=ml fmt -recursive
terraform -chdir=ml init -backend=false
terraform -chdir=ml validate
terraform -chdir=ml test             # fake Azure, nothing is created
```

## Rules (what not to do)

- **Never run `terraform apply`** from here, never create cloud resources.
- **No secrets**, no real IDs, no client or internal system names.
- **People only edit `registry/`.** Changing the schema, `ml/` or the modules is a
  platform-team change, in its own pull request.
- One use case per pull request; do not edit other use cases' files.
- Never give a use case Owner or Contributor.
- A new field: add it to the schema first (optional = minor version, e.g. 1.1.0),
  then use it in `ml/main.tf`, then add a test.
- Mark every guess about the real platform repo with `# ASSUMPTION:`.
- When you change this folder, update this file in the same change.
