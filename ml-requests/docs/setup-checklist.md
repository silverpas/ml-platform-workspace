# Setup checklist (end of step 3)

For the platform lead, after "go" **and** once the data and the priority are
clear (step 3). Turns an approved request into a working project:
**one YAML file** in the platform repo and **one repo** from the template.
Nobody writes Terraform for it.

Example: use case `tool-wear` in department `manufacturing`.

## 1. From the form to the registry file

Every form field marked "→ registry" goes into
`registry/ml_use_cases/<department>__<use_case_id>.yaml` in the platform repo
(copy an existing file there):

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
| (set by you, step 2 below) | `github_repo` | `example-org/ml-tool-wear` |

Also set `schema_version: "1.0.0"` and `status: active`. Only if GitHub's
login later fails with "No matching federated identity record": add
`github_ids` (see the platform repo's onboarding checklist).

The result looks like this:

```yaml
# yaml-language-server: $schema=../schema/ml_use_case.schema.json
schema_version: "1.0.0"
use_case_id: tool-wear
display_name: Tool wear prediction
department: manufacturing
status: active
owner: "[model owner]"
github_repo: "example-org/ml-tool-wear"
risk_tier: decision_support
gpu: false
reads:
  - manufacturing.gold.fact_machine_sensors
predictions_table: ml_tool_wear_predictions
```

## 2. The checklist

- [ ] **Reviewer:** add the approval-gate reviewer's GitHub ID to the file as
      `reviewer_github_ids: [<id>]` (`gh api users/<login> --jq .id`).
- [ ] **Registry file:** open a pull request in the platform repo with the file
      above. If the department has no `registry/ml_workspaces/<department>.yaml`
      yet, add it in the same pull request. Follow the platform repo's
      onboarding checklist (checks, `terraform plan`, approval, apply). The
      apply also creates the project repo `ml-<use_case_id>` from the template,
      with its Azure variables and approval gate. Give the team access to it.
- [ ] **Data access:** after apply, the `data_access_todo` output lists what the
      data owners must grant in Fabric (read on `reads`, write on
      `predictions_table`). Ask them, link their answers here.
- [ ] **Hand-over:** the repo link (`project_repos` output) and the
      `project_clusters` output (the project's own cluster name and machine
      type). The five Azure variables and the approval gate are already set.
- [ ] **Project settings:** in the project repo's `config.yml`, `model.name` =
      `use_case_id` and `scoring.predictions_table` = the registry's
      `predictions_table`, `cost.vm_size` = the cluster's machine type; in
      `jobs/*.yml`, `compute: azureml:<cluster name>`. In `model-card.md`: owner, risk tier, first review date.
- [ ] **Close:** comment with links to the project repo and the registry pull
      request, set the label `set-up`, close this issue.
