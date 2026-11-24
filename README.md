# ML platform workspace

Building blocks for doing machine learning on a Fabric data platform with
Azure Machine Learning, in a controlled, repeatable way. The design is in
[docs/ml-platform-design.md](docs/ml-platform-design.md).

This repo is a development workspace. Each of the four folders will become
its own GitHub repo, so each one is self-contained.

| Folder | What it is | Who uses it |
|---|---|---|
| [`ml-requests/`](ml-requests/README.md) | The front door: request form and process for new ML use cases | Anyone with an idea, platform lead |
| [`ml-infra-template/`](ml-infra-template/README.md) | Terraform modules: one Azure ML workspace per department, one setup per use case | Platform engineers |
| [`cdp-ml-onboarding/`](cdp-ml-onboarding/README.md) | Example of what the platform repo (CDP) gets for each new use case | Platform team, platform lead |
| [`ml-project-template/`](ml-project-template/README.md) | Code template: one repo per use case, from data to approved model to predictions | Data scientists, ML engineers |

## How they fit together

```
 0. Explore     try the idea on your laptop (no request, no shared playground)
 1. Request     ml-requests: issue form                         → label "new"
 2. Qualify     platform lead checks it                         → "approved"
 3. Data        data access and priority agreed; at the end, the project setup:
                ├─ cdp-ml-onboarding: add one use case YAML (modules from ml-infra-template)
                │    → the project's cluster, identity and Azure access
                └─ new repo from ml-project-template, IDs set as GitHub variables
 4. Build       ml-project-template: train → evaluate → approval gate → champion → export
 5. Run/review  nightly batch scoring in Azure ML → Fabric lakehouse → Power BI;
                quarterly review: keep, retrain or retire
```

## Example used everywhere

- Use case `tool-wear`, department `manufacturing`.
- Data: the public [AI4I 2020 Predictive Maintenance dataset](https://archive.ics.uci.edu/dataset/601/ai4i+2020+predictive+maintenance+dataset)
  (UCI Machine Learning Repository, id 601, CC BY 4.0).

No client names, no real company data, no secrets. Nothing here creates cloud
resources: Terraform is only formatted, validated and tested against a fake Azure.

## Checks

[`.github/workflows/check-all.yml`](.github/workflows/check-all.yml) runs each
folder's checks on every push to this workspace. Each folder also has its own
workflows for when it becomes a separate repo.
