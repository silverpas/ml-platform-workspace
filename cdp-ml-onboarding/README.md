# ML registry (platform repo example)

An example of how a data platform's Terraform repo onboards machine learning,
**metadata-driven**: a new ML use case is **one YAML file in a pull request**.

```
registry/ml_workspaces/manufacturing.yaml              turns on ML for a department (once)
registry/ml_use_cases/manufacturing__tool-wear.yaml    one ML use case
        ↓ checked against registry/schema/*.schema.json
ml/  Terraform reads every file → ml-workspace / ml-project modules → plan → approval → apply
```

A use case file looks like this:

```yaml
schema_version: "1.0.0"
use_case_id: tool-wear
department: manufacturing
owner: "[model owner]"
github_repo: "example-org/ml-tool-wear"
risk_tier: decision_support
gpu: false          # the use case's own cluster: CPU (false) or GPU (true)
reads:
  - manufacturing.gold.fact_machine_sensors
predictions_table: ml_tool_wear_predictions
```

- **Onboard a use case:** [docs/onboarding-checklist.md](docs/onboarding-checklist.md)
- **Workflow, commands and rules:** [AGENTS.md](AGENTS.md)
- **The modules behind it:** `ml-infra-template` (`ml-workspace`, `ml-project`)

It is an example to copy from, not a replacement for the real platform repo.
