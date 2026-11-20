# ML platform workspace

This repo is a **development workspace** for four ML platform building blocks
on a Fabric data platform with Azure Machine Learning. Each folder will later
become its own GitHub repo. The design is in @docs/ml-platform-design.md
(single source of truth): read it before making structural decisions.

## Folders

| Folder | Becomes | Users |
|---|---|---|
| `ml-project-template/` | Code template, one repo per ML use case | Data scientists, ML engineers |
| `ml-infra-template/` | Terraform modules `ml-workspace` (per department), `ml-project` (per use case) | Platform engineers |
| `cdp-ml-onboarding/` | Example slice of the platform (CDP) repo: what is added per use case | Platform team, platform lead |
| `ml-requests/` | Request form and process for new ML use cases | Anyone with an idea, platform lead |

- **Self-contained folders**: no imports or relative paths between folders.
  Only exception: `cdp-ml-onboarding/` may use `source = "../ml-infra-template/modules/..."`.
- Each folder has an `AGENTS.md` (for its future users and their agents, not
  for us) and a `CLAUDE.md` containing only `@AGENTS.md`. Every `AGENTS.md`
  covers: purpose, structure, user workflow, commands, rules, place in steps 0-5.
  Under 150 lines, plain language, jargon explained in one line.
- **Whenever you change a folder, update its `AGENTS.md` in the same change.**
- `.github/workflows/check-all.yml` at the root is for this workspace only: it
  runs each folder's checks. It is not copied into the four repos.

## Hard rules (everywhere)

- **Generic only**: no client names, internal system names or real company data.
  Example data: public AI4I 2020 Predictive Maintenance (UCI, id 601), credited
  in the README. Example use case `tool-wear`, department `manufacturing`.
- **No secrets**. Azure login only via OIDC, IDs stored as GitHub variables:
  `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`,
  `AZURE_RESOURCE_GROUP`, `AZURE_ML_WORKSPACE`.
- **Never run `terraform apply`** or create cloud resources. Only `terraform fmt`,
  `init -backend=false`, `validate`, and `terraform test` with the mock provider.
- **Local first**: the ML code runs without Azure (local MLflow
  `sqlite:///mlflow.db`, model files in `./mlruns`, local files).
- Azure ML **SDK v2 / CLI v2** only (`azure-ai-ml`, YAML job specs), never SDK v1.
- **No Terraform in `ml-project-template/`**: infrastructure exists before a project starts.
- Mark guesses about the platform team's setup or OneLake with `# ASSUMPTION:`.
- Ask before adding a dependency.

## Key decisions

- **Scoring runs in Azure ML by default** (design option B): `score.yml` runs
  nightly and submits `jobs/batch-score.yml`, which writes predictions to the
  predictions lakehouse (OneLake). Locally, predictions go to `data/predictions/`.
  `notebooks/fabric_batch_score.ipynb` (option A, PREDICT in Fabric) is optional only.
- One Azure ML workspace per department (`ml-workspace` module), one
  `ml-project` block per use case, added in the platform repo.
- `demo-local-flow.yml` in the project template is a demo of the approval gate
  without Azure (environment `approval-demo`); it is not the production pipeline.

## Tech choices

Python 3.11, pandas, scikit-learn, LightGBM, MLflow, pytest, ruff. GitHub
Actions with OIDC (`azure/login`), deploy behind a GitHub environment with
required reviewers. Terraform with `azurerm` and `azuread`, versions pinned.

## Commands

```bash
# ml-project-template/   (macOS: brew install libomp first)
cd ml-project-template
python3.11 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python -m src.prep && python -m src.train && python -m src.evaluate && python -m src.register
python -m src.register --promote <version>
python -m src.score --input data/raw/ai4i2020.csv --output outputs/predictions.parquet
pytest
ruff check . && ruff format --check .
mlflow ui --backend-store-uri sqlite:///mlflow.db --port 8080

# ml-infra-template/   (for each module in modules/)
terraform -chdir=ml-infra-template/modules/ml-project fmt -recursive
terraform -chdir=ml-infra-template/modules/ml-project init -backend=false
terraform -chdir=ml-infra-template/modules/ml-project validate
terraform -chdir=ml-infra-template/modules/ml-project test

# cdp-ml-onboarding/   (milestone 5)
terraform -chdir=cdp-ml-onboarding/ml init -backend=false
terraform -chdir=cdp-ml-onboarding/ml validate

# ml-requests/: no commands (Markdown and YAML only)
```

Update this section when commands change.

## Milestones

1. Restructure into four folders ✅
2. `ml-project-template`: local pipeline on AI4I with MLflow and tests
3. `ml-project-template`: Azure ML jobs, environment, workflows, notebook, model card
4. `ml-infra-template`: both modules, validated
5. `cdp-ml-onboarding`: CDP example and checklist, validated
6. `ml-requests`: issue form and process docs
7. Final pass: every `AGENTS.md` matches its folder

## How to work with me

- I'm learning MLOps and Terraform: after each milestone, explain briefly what
  you did and why, in simple terms.
- Work in small milestones: propose a plan, implement one milestone, then stop
  and wait for my review.
- Prefer simple and readable over clever.
- Commit after each milestone with a clear message.
