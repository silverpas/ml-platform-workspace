# Onboarding a new ML use case

A new ML use case is **one YAML file in a pull request**. Nobody writes
Terraform for it: the platform's Terraform reads the file and does the rest.

Example used below: use case `tool-wear` in department `manufacturing`.

## 0. Before you start

- [ ] The request is approved (step 2 "Qualify") and step 3 is done: the data
      and the priority are clear. Projects are set up at the end of step 3.
- [ ] There is a **model owner**
      and a **risk tier** (`exploration`, `decision_support` or `production_critical`).
- [ ] The data the model needs is in the platform, and you know its tables
      (`<domain>.<layer>.<table>`, e.g. `manufacturing.gold.fact_machine_sensors`).
- [ ] The project repo exists, created from `ml-project-template` with
      **Use this template** (e.g. `example-org/ml-tool-wear`).

## 1. Is ML turned on for the department?

Look for `registry/ml_workspaces/<department>.yaml`.

- **It exists:** go to step 2.
- **It does not:** add it in the same pull request (copy
  `registry/ml_workspaces/manufacturing.yaml`). This creates the department's
  Azure ML workspace and `cpu-cluster` (about 5-10 EUR per month while it exists).

## 2. Add the use case file

Copy `registry/ml_use_cases/manufacturing__tool-wear.yaml` to
`registry/ml_use_cases/<department>__<use_case_id>.yaml` and fill it in.
In VS Code the first line gives autocomplete and underlines mistakes.

| Field | What to write |
|---|---|
| `use_case_id` | Short name, lowercase with hyphens: the same as the model and the repo (`ml-<id>`) |
| `department` | The department; its `ml_workspaces` file must exist |
| `owner` | The model owner |
| `github_repo` | `org/repo` of the project repo; only this repo can log in to Azure |
| `risk_tier` | From qualification |
| `gpu` | `false` unless the model needs a GPU (deep learning) |
| `reads` | The tables the model reads |
| `predictions_table` | Gold table for the predictions, starting with `ml_` |

## 3. Open the pull request

The checks run by themselves:

- every file follows its schema (`tests/test_registry.py`);
- the file name matches its content, the department has a workspace;
- `terraform plan` shows what will be created.

**Read the plan.** For a new use case in an existing department you should see
only: one identity, two federated credentials (the repo's `main` branch and its
`production` environment) and one role assignment *AzureML Data Scientist*.
Never Owner or Contributor. **Nothing destroyed.**

## 4. Merge and apply

After review and merge, the platform's workflow applies the reviewed plan,
after a human approval.

## 5. Data access (in Fabric)

The `data_access_todo` output lists what is still needed:

- [ ] The owner of each table in `reads` grants read access to the use case's
      identity (`identity_principal_id`).
- [ ] Write access to the Gold lakehouse for `predictions_table`.

## 6. Hand over to the project team

The `github_variables` output gives five values for the project repo
(*Settings → Secrets and variables → Actions → Variables*):
`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`,
`AZURE_RESOURCE_GROUP`, `AZURE_ML_WORKSPACE`.

Also tell them to create the `production` environment with the reviewers.

## Retiring a use case

Set `status: retired` in its file (keep the file for the record). The next apply
removes its identity and access. The models and runs stay in the workspace.
