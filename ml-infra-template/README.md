# ML infrastructure template

Terraform modules for machine learning on Azure, proposed to the platform team.

| Module | Used | Creates |
|---|---|---|
| `modules/ml-workspace` *(milestone 4)* | once per department | Azure ML workspace, storage, key vault, Application Insights, compute clusters |
| [`modules/ml-project`](modules/ml-project/README.md) | once per ML use case | Login identity for the project's GitHub Actions, access to the workspace, outputs for GitHub variables |

These modules are run from the platform team's own repo, never from here.
See [AGENTS.md](AGENTS.md) for the workflow, commands and rules.

```bash
terraform -chdir=modules/ml-project init -backend=false
terraform -chdir=modules/ml-project validate
terraform -chdir=modules/ml-project test    # fake Azure, nothing is created
```
