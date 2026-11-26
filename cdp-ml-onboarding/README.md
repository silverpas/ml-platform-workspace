# ML registry (platform repo example)

An example of how a data platform's Terraform repo onboards machine learning,
**metadata-driven**: a new ML project is **one YAML file in a pull request**.

```
registry/ml_use_cases/manufacturing__tool-wear.yaml    one ML project
        ↓ checked against registry/schema/ml_use_case.schema.json
ml/  Terraform reads every file → per project: resource group, Azure ML workspace,
     identity, cluster, GitHub repo → plan → approval → apply
```

Each project gets **its own resource group** (`rg-ml-<department>-<use_case>`)
with everything inside: projects are fully separated.

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
