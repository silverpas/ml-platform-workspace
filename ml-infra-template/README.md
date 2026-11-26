# ML infrastructure template

Terraform modules for machine learning on Azure, proposed to the platform team.

| Module | Used | Creates |
|---|---|---|
| [`modules/ml-workspace`](modules/ml-workspace/README.md) | once per ML project, in its own resource group | Azure ML workspace, storage, key vault, Application Insights, container registry (no compute) |
| [`modules/ml-project`](modules/ml-project/README.md) | once per ML use case | The project's identity (GitHub Actions login and jobs), **its own cluster** (CPU or GPU, scales to 0, tagged per project), access to the workspace, optional team group, outputs for GitHub variables |
| [`modules/ml-project-github`](modules/ml-project-github/README.md) | once per ML use case, with `ml-project` | The project's **GitHub repo** from the template, its five Azure variables, the `production` environment (approval gate) and the GitHub login rules: the repo is ready to run |

These modules are run from the platform team's own repo, never from here.
Names have defaults but can come from outside (`names`), to fit the platform's
naming rules; an `environment` (dev/prod) is optional and off by default.
See [AGENTS.md](AGENTS.md) for the workflow, commands and rules.

```bash
# for each module: ml-workspace, ml-project, ml-project-github
terraform -chdir=modules/ml-workspace init -backend=false
terraform -chdir=modules/ml-workspace validate
terraform -chdir=modules/ml-workspace test    # fake Azure and GitHub, nothing is created
```
