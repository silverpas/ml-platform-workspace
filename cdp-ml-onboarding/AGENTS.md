# AGENTS.md: ML registry for the platform repo

Instructions for platform engineers who onboard ML use cases, and for their
AI coding agents.

## What this repo is for

An **example of the platform repo's ML registry**. Onboarding is
**metadata-driven**: a new ML use case is one YAML file in a pull request.
Terraform reads every file and calls the shared modules from
`ml-infra-template` once per file. Nobody writes Terraform per use case.

It is an **example**: copy the pattern into the real platform repo; do not
apply it from here. If the platform already has a registry with a resolver
(YAML → contract → Terraform), these files become a new object type there.

Jargon in one line each:
- **Registry**: a folder of YAML files that describe what should exist.
- **JSON schema**: a file with the rules a YAML file must follow (fields, formats).
- **Metadata-driven**: you describe *what* you want in a file; code does the *how*.
- **`terraform plan`**: a dry run that lists what would be created or changed.
- **Outputs**: values Terraform prints after apply (here: IDs for GitHub variables).

## Where this repo sits in the overall process

| Step | What happens | This repo? |
|---|---|---|
| 0. Explore | Try the idea | No |
| 1. Request | Request form (ml-requests repo; same field names as the YAML) | No |
| 2. Qualify | Go → **add one use case YAML** (and the department's workspace YAML if new) | **Yes** |
| 3. Data and priority | `reads` and `predictions_table`; access granted in Fabric | **Yes** |
| 4. Build | Hand the `github_variables` output to the project team | **Yes: hand-over** |
| 5. Run and review | Retire = `status: retired` | **Yes** |

## Folder structure

```
registry/
  ml_workspaces/<department>.yaml               ONCE per department: turns on ML
  ml_use_cases/<department>__<use_case>.yaml    ONE per ML use case
  schema/ml_workspace.schema.json               rules for the files above
  schema/ml_use_case.schema.json
ml/                     Terraform: reads the registry, calls the modules
  main.tf               one module per file (for_each), cross-file checks
  outputs.tf            registry_checks, github_variables, data_access_todo
  variables.tf          registry_dir (only tests change it)
  versions.tf           pinned providers (azurerm ~> 4.81, azuread ~> 3.10)
  tests/                terraform test with a fake Azure; tests/fixtures/ = small
                        test registries (good and broken)
tests/                  pytest: schema and cross-file checks
  invalid/              broken YAML examples the schema must refuse
docs/onboarding-checklist.md   step by step, for a person
requirements.txt        jsonschema, pyyaml, pytest (tests only)
```

In this example only, module `source` points to `../../ml-infra-template/modules/...`
so it validates locally. In the real repo it points to wherever the platform
team keeps the modules. The modules use default names (`mlw-<department>`, ...);
if the platform defines names centrally, `ml/main.tf` passes them in with
`names = { ... }`. The cluster name goes from `ml_workspace` to `ml_project`.

## Workflow: onboard a new ML use case

Follow [docs/onboarding-checklist.md](docs/onboarding-checklist.md). In short:

1. If the department has no `registry/ml_workspaces/<department>.yaml`, add it.
2. Add `registry/ml_use_cases/<department>__<use_case_id>.yaml`.
3. Open a pull request: schema checks and `terraform plan` run.
4. Check the plan: only this use case's identity, two federated credentials and
   one *AzureML Data Scientist* role; nothing destroyed.
5. Review, merge, apply (platform team, after approval, in the real repo).
6. Grant data access in Fabric (`data_access_todo` output) and hand the
   `github_variables` output to the project team.

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
