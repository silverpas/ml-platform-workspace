# ML project template

This repo is a **template for ML projects** on a Fabric data platform with Azure
Machine Learning. Every new ML use case will start from it. The full design is in
@docs/ml-platform-design.md: read it before making structural decisions.

## Hard rules

- **Generic only.** No client names, internal system names or real company data.
  Use the public AI4I 2020 Predictive Maintenance dataset (UCI, id 601) for examples.
- **No secrets** in code, config or commits. Azure access goes through OIDC and
  environment variables.
- **Never run `terraform apply`** or create cloud resources. `terraform fmt` and
  `terraform validate` are fine.
- **Everything must run locally first**, without an Azure account: local MLflow
  tracking (`sqlite:///mlflow.db` for runs and registry, model files in `./mlruns`)
  and local files. Azure is an optional second mode.
- Ask before adding a new dependency.

## Target structure

```
README.md, AGENTS.md, model-request.yml, model-card.md
src/            prep.py, train.py, evaluate.py, register.py, score.py
jobs/           train-register.yml, batch-score.yml   (Azure ML CLI v2 job specs)
environment/    conda.yml
tests/
.github/workflows/  ci.yml, train.yml, deploy.yml
infra/modules/ml-project/   Terraform module (azurerm), one block per use case
data/           local data only, git-ignored
```

- **Scoring runs in Azure ML** (design doc option B): `jobs/batch-score.yml` runs
  `src/score.py` and writes predictions to a Fabric lakehouse. Fabric PREDICT
  (option A) is not part of the template.
- **Department workspaces are not in this repo.** The platform team creates one
  Azure ML workspace per department; `ml-project` only plugs a use case into it.
- `terraform test` with the mock provider is fine (no Azure, nothing is created).

## Tech choices

- Python 3.11, pandas, scikit-learn, LightGBM, MLflow, pytest, ruff.
- Azure ML **SDK v2 / CLI v2** only (`azure-ai-ml`, YAML job specs). Never SDK v1.
- GitHub Actions with OIDC (`azure/login`), deploy behind a GitHub environment
  with required reviewers (the approval gate).
- Terraform with the `azurerm` provider.

## Code conventions

- Each script in `src/` is a CLI with `argparse`, reads inputs from paths and writes
  outputs to paths, so it runs the same locally and as an Azure ML job.
- Settings in YAML or CLI arguments, not hard-coded.
- Every training run logs to MLflow: parameters, metrics, the **data version**
  (file path or table version) and the **git commit**.
- `evaluate.py` compares the new model with the current registered version and
  only marks it as a candidate if it is better on the same test set.
- Small, focused functions with type hints and short docstrings.
- Tests for data prep and evaluation logic; no tests that need Azure.
- Prefer simple and readable over clever. This template must be easy for
  people who are new to ML to understand.

## Commands

```bash
brew install libomp          # macOS only: LightGBM needs it
python3.11 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python -m src.prep --out data/processed      # downloads AI4I if missing
python -m src.train --data data/processed
python -m src.evaluate                        # writes outputs/evaluation.json
python -m src.register                        # registers as "candidate" if better
python -m src.register --promote <version>    # approve: set "champion"
python -m src.score --input data/raw/ai4i2020.csv --output outputs/predictions.parquet
pytest
ruff check . && ruff format --check .
mlflow ui --backend-store-uri sqlite:///mlflow.db --port 8080   # view runs locally
terraform -chdir=infra/modules/ml-project fmt -recursive
terraform -chdir=infra/modules/ml-project init -backend=false
terraform -chdir=infra/modules/ml-project validate
terraform -chdir=infra/modules/ml-project test   # mock provider, no Azure
```

Update this section when commands change.
