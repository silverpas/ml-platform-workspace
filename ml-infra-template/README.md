# ML infrastructure template

Terraform modules for machine learning on Azure, proposed to the platform team.

| Module | Used | Creates |
|---|---|---|
| [`modules/ml-workspace`](modules/ml-workspace/README.md) | once per department | Azure ML workspace, storage, key vault, Application Insights, container registry, `cpu-cluster` (scales to 0), optional `gpu-cluster` |
| [`modules/ml-project`](modules/ml-project/README.md) | once per ML use case | Login identity for the project's GitHub Actions, access to the workspace, optional team group, outputs for GitHub variables |

These modules are run from the platform team's own repo, never from here.
Names have defaults but can come from outside (`names`), to fit the platform's
naming rules; an `environment` (dev/prod) is optional and off by default.
See [AGENTS.md](AGENTS.md) for the workflow, commands and rules.

```bash
# for each module: ml-workspace, ml-project
terraform -chdir=modules/ml-workspace init -backend=false
terraform -chdir=modules/ml-workspace validate
terraform -chdir=modules/ml-workspace test    # fake Azure, nothing is created
```
