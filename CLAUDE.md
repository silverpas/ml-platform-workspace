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
- `publish-template.sh` at the root is also workspace only: it publishes the
  `ml-project-template/` folder to its own GitHub template repo.

## Hard rules (everywhere)

- **Generic only**: no client names, internal system names or real company data.
  Example data: public AI4I 2020 Predictive Maintenance (UCI, id 601), credited
  in the README. Example use case `tool-wear`, department `manufacturing`.
- **No secrets**. Azure login only via OIDC, IDs stored as GitHub variables:
  `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`,
  `AZURE_RESOURCE_GROUP`, `AZURE_ML_WORKSPACE`.
- **Never run `terraform apply`** or create cloud resources. Only `terraform fmt`,
  `init -backend=false`, `validate`, and `terraform test` with the mock provider.
  **One exception, the personal sandbox:** in the git-ignored `docs/private/`
  folder, the user herself may run `terraform plan` and `apply` against her own
  test resource group, after reviewing the plan with Claude. Claude writes the
  files and explains, but never runs `apply` or `destroy`. Real names stay there.
- **Local first**: the ML code runs without Azure (local MLflow
  `sqlite:///mlflow.db`, model files in `./mlruns`, local files).
- Azure ML **SDK v2 / CLI v2** only (`azure-ai-ml`, YAML job specs), never SDK v1.
- **No Terraform in `ml-project-template/`**: infrastructure exists before a project starts.
- Mark guesses about the platform team's setup or OneLake with `# ASSUMPTION:`.
- Ask before adding a dependency.

## Key decisions

- **Scoring runs in Azure ML by default** (design option B): `score.yml` runs
  nightly and submits `jobs/batch-score.yml`, which writes predictions as a Delta
  table to a Gold `ml_` table (`scoring.predictions_table` in `config.yml`, the
  same as the registry YAML's `predictions_table`). Locally, the same Delta table
  goes to `data/predictions/<predictions_table>/`.
  `notebooks/fabric_batch_score.ipynb` (option A, PREDICT in Fabric) is optional only.
- **Azure ML is the ML platform.** One Azure ML workspace per department
  (`ml-workspace` module, no compute), one `ml-project` per use case, which
  creates the project's **own cluster** with the project's identity and tags
  (data access and costs per project).
- **Project setup at the end of step 3** (data and priority clear), not right
  after "go". No shared playground: step 0 is local.
- **Portable**: data reading behind one function (`src/data.py`), the approved
  model exported as a standard MLflow folder (`src/export.py`), an estimated
  cost per run in MLflow.
- **Fabric connection is documented, not built** (design section 9). Until then
  the jobs upload the example CSV and write the predictions Delta table to the
  job's output `predictions`.
- **Metadata-driven onboarding**: a new ML use case is one YAML file in the
  platform repo's ML registry (`registry/ml_use_cases/<department>__<id>.yaml`,
  checked against a JSON schema with `jsonschema`). Terraform reads the files and
  calls the modules; nobody writes module blocks per use case.
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
python -m src.export                                # approved model -> outputs/export/
python -m src.score --input data/raw/ai4i2020.csv   # Delta table in data/predictions/
pip install -r requirements-azure.txt               # Azure ML from the laptop: docs/azure-sandbox.md
pytest
ruff check . && ruff format --check .
mlflow ui --backend-store-uri sqlite:///mlflow.db --port 8080

# ml-infra-template/   (for each module in modules/)
terraform -chdir=ml-infra-template/modules/ml-project fmt -recursive
terraform -chdir=ml-infra-template/modules/ml-project init -backend=false
terraform -chdir=ml-infra-template/modules/ml-project validate
terraform -chdir=ml-infra-template/modules/ml-project test

# cdp-ml-onboarding/   (registry YAML + Terraform that reads it)
cd cdp-ml-onboarding && pytest && cd ..        # schema checks (jsonschema)
terraform -chdir=cdp-ml-onboarding/ml init -backend=false
terraform -chdir=cdp-ml-onboarding/ml validate
terraform -chdir=cdp-ml-onboarding/ml test

# ml-requests/: no commands (Markdown and YAML only)

# workspace root: publish ml-project-template/ to its GitHub template repo
./publish-template.sh
```

Update this section when commands change.

## Milestones

1. Restructure into four folders ✅
2. `ml-project-template`: local pipeline on AI4I with MLflow and tests ✅
3. `ml-project-template`: Azure ML jobs, environment, workflows, notebook, model card ✅
4. `ml-infra-template`: both modules, validated ✅
5. `cdp-ml-onboarding`: ML registry (YAML + schema), Terraform reading it, checklist, validated ✅
6. `ml-requests`: issue form (same fields as the registry YAML) and process docs ✅
7. Final pass: every `AGENTS.md` matches its folder ✅

Phase 2: end to end in a personal Azure ML sandbox (CPU only, small quota).

8. Decisions in the docs (cluster per project, setup at end of step 3, Fabric later) ✅
9. `ml-project-template`: data reading behind one function (`src/data.py`) ✅
10. `ml-project-template`: model export after approval (`src/export.py`) ✅
11. `ml-project-template`: estimated cost per run ✅
12. `ml-infra-template` + `cdp-ml-onboarding`: one cluster per project ✅
13. Sandbox-ready: jobs on uploaded data, guide `docs/azure-sandbox.md` ✅
    (the real run in the sandbox is done by the user)
14. Later: the Fabric connection (design section 9)

## How to work with me

- I'm learning MLOps and Terraform: after each milestone, explain briefly what
  you did and why, in simple terms.
- Work in small milestones: propose a plan, implement one milestone, then stop
  and wait for my review.
- Prefer simple and readable over clever.
- Commit after each milestone with a clear message. No `Co-Authored-By` or
  other Claude attribution lines in commit messages.
