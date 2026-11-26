# Setup checklist (end of step 3)

For the platform lead, once a request is approved **and** the data and the
priority are clear. It turns the request into a working project. You write one
YAML file; the platform does the rest. Nobody writes Terraform by hand.

Example: use case `tool-wear` in department `manufacturing`.

## What one YAML file gives the project

When the file is merged and applied in the platform repo, the project gets:

- **its own resource group** on Azure, `rg-ml-<department>-<use_case_id>`, with
  everything inside: an Azure ML workspace (with storage, key vault, container
  registry and logs), the project's identity and its compute cluster;
- **its own GitHub repo**, `ml-<use_case_id>`, copied from the project
  template, with the five Azure variables, the approval gate and the login to
  Azure already set up.

It costs about 5-10 EUR per month while it exists, plus the cluster while it
runs jobs.

## 1. From the form to the registry file

Every form field marked "→ registry" goes into
`registry/ml_use_cases/<department>__<use_case_id>.yaml` in the platform repo.
Copy an existing file there and change it.

| Form field | Registry field | Example |
|---|---|---|
| Use case name | `use_case_id` | `tool-wear` |
| Readable name | `display_name` | `Tool wear prediction` |
| Department | `department` | `manufacturing` |
| Model owner | `owner` | `"[model owner]"` |
| Risk tier (as agreed at qualification) | `risk_tier` | `decision_support` |
| Data the model needs | `reads` (a list) | `manufacturing.gold.fact_machine_sensors` |
| Predictions table (empty = `ml_<name>_predictions`, hyphens become `_`) | `predictions_table` | `ml_tool_wear_predictions` |
| Does the model need a GPU? | `gpu` | `false` |
| (you choose it) | `github_repo` | `example-org/ml-tool-wear` |
| (the reviewer from qualification) | `reviewer_github_ids` | `[1234567]` (`gh api users/<login> --jq .id`) |

Also set `schema_version: "1.0.0"` and `status: active`.

The file looks like this:

```yaml
# yaml-language-server: $schema=../schema/ml_use_case.schema.json
schema_version: "1.0.0"
use_case_id: tool-wear
display_name: Tool wear prediction
department: manufacturing
status: active
owner: "[model owner]"
github_repo: "example-org/ml-tool-wear"
reviewer_github_ids: [1234567]
risk_tier: decision_support
gpu: false
reads:
  - manufacturing.gold.fact_machine_sensors
predictions_table: ml_tool_wear_predictions
```

## 2. The checklist

- [ ] **Registry file:** open a pull request in the platform repo with the
      file. The checks and `terraform plan` run; follow the platform repo's
      onboarding checklist to read the plan. After approval it is applied.
- [ ] **Team access:** give the model owner and team access to the new repo
      (`project_repos` output).
- [ ] **Data access:** the `data_access_todo` output lists what the data owners
      must grant in Fabric (read on `reads`, write on `predictions_table`).
      Ask them, and link their answers on the issue.
- [ ] **Project settings:** in the new repo, check `config.yml`: `model.name` =
      `use_case_id`, `scoring.predictions_table` = the file's
      `predictions_table`, `cost.vm_size` = the cluster's machine type
      (`project_clusters` output); and `compute: azureml:<cluster name>` in
      `jobs/*.yml`. In `model-card.md`: owner, risk tier, first review date.
- [ ] **Close:** comment with links to the repo and the registry pull request,
      set the label `set-up`, and close the issue.
