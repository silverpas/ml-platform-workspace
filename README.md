# ML project template

A starting point for every new machine learning use case on a Fabric data
platform with Azure Machine Learning. One GitHub repo per use case: create it
from this template, swap the example for your own data, and keep the rest.

The example inside predicts **machine failures** from sensor readings, using
the public [AI4I 2020 Predictive Maintenance dataset](https://archive.ics.uci.edu/dataset/601/ai4i+2020+predictive+maintenance+dataset).

## How a model goes from data to report

```
Fabric lakehouse (training data snapshot)
  → Azure ML: prep → train → evaluate        only a better model continues
  → registered as "candidate"
  → reviewer approves in GitHub               the model becomes "champion"
  → Azure ML: batch scoring with the champion
  → Fabric lakehouse (predictions table) → Power BI
```

Everything also runs **on your laptop**, without Azure: local files instead of
the lakehouse, and a local MLflow store instead of the Azure ML workspace.
The full design is in [docs/ml-platform-design.md](docs/ml-platform-design.md).

## Run it locally

Needs Python 3.11. On macOS, LightGBM also needs `brew install libomp`.

```bash
python3.11 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

python -m src.prep          # download and prepare the data
python -m src.train         # train a model
python -m src.evaluate      # compare it with the approved model
python -m src.register      # register it as "candidate" if it is better
python -m src.register --promote 1     # approve version 1 as "champion"
python -m src.score --input data/raw/ai4i2020.csv --output outputs/predictions.parquet

pytest                      # run the tests
ruff check .                # check code style
mlflow ui --backend-store-uri sqlite:///mlflow.db --port 8080   # browse runs at localhost:8080
```

## Try the whole flow on GitHub (no Azure needed)

The **Demo pipeline** workflow runs train → approval → scoring on GitHub's own
computers:

1. Open the **Actions** tab → *Demo pipeline (no Azure)* → **Run workflow**.
2. When training is done, the run page shows the new model next to the
   current champion, and the decision.
3. If the new model is better, the run pauses at **Review deployments**:
   a reviewer approves or rejects.
4. After approval, the model becomes champion and the predictions can be
   downloaded from the run page.

To see a second model compete, change a setting under `model.params` in
`config.yml` and push.

## Folders

| Path | What it is | Change it for a new use case? |
|---|---|---|
| `config.yml` | All settings: data, target column, columns to drop, model, metric | **Yes**, the main place |
| [`src/`](src/README.md) | The five pipeline steps | Only `prep.py`, if your data needs different cleaning |
| [`tests/`](tests/README.md) | Automatic checks on fake data | Adapt the fake data, add tests for your cleaning |
| `requirements.txt` | Python packages with exact versions | Rarely |
| `pyproject.toml` | Settings for pytest and ruff | No |
| [`infra/`](infra/README.md) | Terraform module, used by the platform team | No |
| `docs/` | Platform design document | No |
| `CLAUDE.md` | Rules for AI coding assistants | No |
| [`.github/workflows/`](.github/workflows/README.md) | Automatic checks on every push, and the demo flow with the approval gate | No |
| `jobs/`, `environment/` | Azure ML job files and packages | *coming next* |

Created locally and never committed: `data/`, `outputs/`, `mlflow.db`, `mlruns/`, `.venv/`.

## Start a new use case

1. Create a repo from this template ("Use this template" on GitHub).
2. In `config.yml`, change the `data` section (source, target, columns to drop)
   and `model.name`.
3. If your data is not a zipped CSV, or needs other cleaning, adapt
   `load_raw` / `prepare` in `src/prep.py`.
4. Change the fake data in `tests/conftest.py` to your columns.
5. Run the pipeline and `pytest` locally until the tests pass and the metrics make sense.
6. Ask the platform team to set up Azure for the project (`infra/`).

## Rules

- **No secrets** in code, config or commits. Azure login goes through OIDC.
- **No real company data** in the repo. `data/` is never committed.
- **A model is used only after approval**: it must beat the current model on
  the same test set, and a reviewer must approve it.
- **Every run is traceable**: MLflow records the data fingerprint, the git
  commit, the settings and the metrics.
