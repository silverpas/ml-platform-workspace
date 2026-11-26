# Onboarding a new ML use case

A new ML project is **one YAML file in a pull request**. Nobody writes
Terraform for it: the platform's Terraform reads the file and creates the
project's resource group, Azure ML workspace, identity, cluster and GitHub repo.

Example used below: use case `tool-wear` in department `manufacturing`.

## 0. Before you start

- [ ] The request is approved (step 2 "Qualify") and step 3 is done: the data
      and the priority are clear. Projects are set up at the end of step 3.
- [ ] There is a **model owner**
      and a **risk tier** (`exploration`, `decision_support` or `production_critical`).
- [ ] The data the model needs is in the platform, and you know its tables
      (`<domain>.<layer>.<table>`, e.g. `manufacturing.gold.fact_machine_sensors`).
- [ ] The project has a name for its repo, e.g. `example-org/ml-tool-wear`
      (the apply creates it from `ml-project-template`).

## 1. Costs to know

Every project gets its own resource group and workspace: about 5-10 EUR per
month while it exists (registry, storage, logs), plus its cluster only while
it runs jobs. Retiring the project removes all of it.

## 2. Add the use case file

Copy `registry/ml_use_cases/manufacturing__tool-wear.yaml` to
`registry/ml_use_cases/<department>__<use_case_id>.yaml` and fill it in.
In VS Code the first line gives autocomplete and underlines mistakes.

| Field | What to write |
|---|---|
| `use_case_id` | Short name, lowercase with hyphens: the same as the model and the repo (`ml-<id>`) |
| `department` | The department (used in names and tags) |
| `owner` | The model owner |
| `github_repo` | `org/repo` of the project repo; only this repo can log in to Azure |
| `risk_tier` | From qualification |
| `gpu` | `false` unless the model needs a GPU (deep learning) |
| `reads` | The tables the model reads |
| `predictions_table` | Gold table for the predictions, starting with `ml_` |
| `resource_group` *(optional)* | Only to use an **existing** resource group; left out = `rg-ml-<department>-<use_case_id>` is created |
| `location` *(optional)* | Azure region of a new resource group; left out = the platform's default |
| `names` *(optional)* | Own names for the workspace resources (platform naming rules) |
| `reviewer_github_ids` *(optional)* | GitHub user IDs who approve model versions |

## 3. Open the pull request

The checks run by themselves:

- every file follows its schema (`tests/test_registry.py`);
- the file name matches its content, each project has its own resource group;
- `terraform plan` shows what will be created.

**Read the plan.** For a new project you should see only its own resources: a
resource group, a workspace with its storage, key vault, container registry
and logs, an identity, a cluster, two role assignments (*AzureML Data
Scientist*, *AcrPull*; never Owner or Contributor), and on GitHub a repo, five
variables, an environment and two federated credentials. **Nothing destroyed.**

## 4. Merge and apply

After review and merge, the platform's workflow applies the reviewed plan,
after a human approval.

## 5. Data access (in Fabric)

The `data_access_todo` output lists what is still needed:

- [ ] The owner of each table in `reads` grants read access to the use case's
      identity (`identity_principal_id`).
- [ ] Write access to the Gold lakehouse for `predictions_table`.

## 6. Hand over to the project team

The apply has also prepared GitHub (`manage_github = true`, the default): the
project repo from the template (output `project_repos`), its five Azure
variables, the `production` environment with the reviewers from
`reviewer_github_ids`, and the GitHub login rules. Give the team the repo link.
(With `manage_github = false`, set the five `github_variables` and the
environment by hand.)

The `project_clusters` output gives the project's own cluster: its name goes
into `compute:` in the project's `jobs/*.yml`, its machine type into
`config.yml` (`cost.vm_size`, for the cost estimate).

Only with `manage_github = false`: if the project's first GitHub workflow
fails to log in with *"No matching federated identity record"*, GitHub sends
the repo with numeric IDs. Add them to the use case file and apply again:
`github_ids: { owner_id: <n>, repo_id: <n> }`
(`gh api repos/<org>/<repo> --jq '.owner.id, .id'`).

## Retiring a use case

Set `status: retired` in its file (keep the file for the record). The next apply
removes its identity, its cluster and its access. The models and runs stay in the workspace.
