# ML platform design: intake process, architecture and templates

> **Status:** draft for discussion. This document is generic on purpose: it uses no
> client names or data. Examples use public data only. Anything marked
> *(proposed)* does not exist yet; anything marked *(in place)* is assumed to exist
> in a typical setup with a Fabric data platform.

## 1. Purpose

Organizations with a data platform in Microsoft Fabric often want to start using
machine learning, but have no dedicated ML team and no shared way of working.
Every project then builds its own setup, which leads to duplicated work, separate
security reviews and models nobody can maintain.

This design proposes **self-service with control**:

- one simple **intake process** from idea to running model;
- one **platform pattern**: data in Fabric, ML in Azure Machine Learning;
- two **templates** so every new use case starts from the same place:
  a GitHub repo template (code) and Terraform modules (infrastructure);
- a **request repo** as the front door, and an **onboarding example** that shows
  what the platform repo gets per use case (see section 5).

## 2. Principles

1. **Explore freely, standardize production.** Early experiments need no process.
   Only the path to production is standardized.
2. **The data platform is the single source of truth.** ML reads data from Fabric
   and writes results back to Fabric. No second data platform.
3. **Small steps.** Build the minimum, test it on one real use case, then extend.
4. **Templates over documents.** People follow what is easy. A template that works
   out of the box is the best enforcement.
5. **MLflow everywhere.** Tracking, model format and registry use MLflow, so the
   same model works in Azure ML, in Fabric and locally.
6. **Control at two points.** Before starting a project (qualify) and before using
   a model (approval gate). Everything in between is self-service.

## 3. Intake process

| Step | What happens | Who | Output | Runs on |
|---|---|---|---|---|
| **0. Explore** (optional) | Try the idea, no request needed | Anyone | An idea worth a request | Own laptop, data the person may already see (no shared playground) |
| **1. Request** | Describe problem, value and how predictions will be used | Requester | Request issue (form) | GitHub, `ml-requests` repo *(proposed)* |
| **2. Qualify** | Is there value? Is ML the right tool? Owner and risk tier | Platform lead + requester | Go / not now / no | The request issue |
| **3. Data and priority** | Is the data in the platform? If not, raise a data request. **At the end: project setup** | Platform lead, data owners | Data access, priority; one YAML file in the platform repo, repo from template | Fabric data domains *(in place)*, ML registry YAML + Terraform modules *(proposed)* |
| **4. Build** | Project from template: train, register, approval gate, model export | Model owner and team | Approved and exported model version | Azure ML *(decided)*, GitHub template *(proposed)* |
| **5. Run and review** | Monitor; keep, retrain or retire | Model owner | Review decision | Power BI *(in place)*, endpoint or local *(proposed)* |

The project is set up **at the end of step 3**, not right after "go": only
when the data and the priority are clear, so no workspace or repo waits empty.

**Risk tiers** (set in step 2) decide how strict later steps are:

| Tier | Example | Before going live |
|---|---|---|
| Exploration | Analysis, prototypes | Cannot go live |
| Decision support | Predictions shown in reports | Owner + reviewer approve |
| Production-critical | Model affects machines or operations | Owner + reviewer + operations sign-off, local fallback plan |

## 4. Architecture

### 4.1 Setup (once per use case)

- **Terraform** in the central platform repo *(in place)* creates the infrastructure.
- **Azure ML is the ML platform** *(decided)*: training, tracking, registry and scoring.
- **One resource group per ML project** *(decided, see
  [decision 0001](decisions/0001-one-resource-group-per-ml-project.md))*, with
  everything the project needs inside: its own Azure ML workspace (experiments,
  model registry) with storage, key vault, container registry and logs, plus the
  project's identity and compute cluster. Projects are fully separated; the
  resource group's bill is the project's cost.
- **One compute cluster per project**, running as the project's own identity
  (which decides what data the project can reach). It scales to 0 nodes when idle.
- **One GitHub repo per use case** *(proposed)*, created from the template repo.
- **Metadata-driven onboarding** *(proposed)*: ordering a project = adding **one
  YAML file** in the platform repo's ML registry, in a pull request, plus **one repo
  from the template**. Nobody writes Terraform per use case: the platform's Terraform
  reads every registry file and calls the shared modules for each one (plan, human
  approval, apply). This follows the pattern data platforms often already use for
  departments and data sources ("a new domain starts as one YAML file").

```
registry/ml_use_cases/<department>__<use-case>.yaml   one file per ML project
        ↓ checked against a JSON schema in the pull request
Terraform reads the files → per project: resource group → ml-workspace → ml-project
        → ml-project-github → plan → approval → apply
```

### 4.2 Each model run

```
Fabric data (versioned snapshot)
  → Training (Azure ML job on the project's cluster, MLflow tracking, estimated cost)
  → Approval gate (Azure ML registry, owner + reviewer)
  → Model export (standard MLflow folder: runs in Azure ML, Fabric or locally)
  → Scoring: Azure ML batch job, nightly (default; optional: Fabric PREDICT)
  → Predictions table (Fabric lakehouse)
  → Power BI (existing reports)
```

Until the Fabric connection exists (section 9), the same chain runs with a
public file as input and a job output folder as the predictions table.

### 4.3 Scoring options

**Default: B, batch scoring in Azure ML.** A nightly GitHub workflow (`score.yml`)
submits the `batch-score` job; it loads the approved model version from the
registry, scores the input data and writes the predictions as a Delta table to a
Gold table with the `ml_` prefix (e.g. `ml_tool_wear_predictions`), straight into
the lakehouse's Tables over OneLake, so Power BI can read it. Option A stays available as an
**optional** notebook for teams that prefer to score inside Fabric.

| | A. Score in Fabric *(optional)* | B. Score in Azure ML *(default)* |
|---|---|---|
| How | Approved model copied to the Fabric registry, scored with `PREDICT` next to the data | Azure ML batch job reads data from OneLake and writes predictions back |
| Good for | Tabular models (scikit-learn, LightGBM, XGBoost) | Deep learning, GPU, models PREDICT can't handle |
| Limits | MLflow format with signature required; no multi-tensor inputs; uses Fabric capacity | Needs write access to a lakehouse; one more place to monitor |

In both cases the **Azure ML registry is the source of truth** for which model version
is approved.

### 4.4 Training data versioning

Every training run logs which data it used:

- **Delta table version** (no copy): log table name and version, read later with
  time travel. Old versions disappear after the table's retention period.
- **Exported files** (frozen copy): write the training data as Parquet to a dated folder,
  e.g. `Files/ml/<use-case>/<date>/`. Needed when Azure ML reads through the OneLake
  datastore (Files folder only), and safer for long-term reproducibility.

### 4.5 Portable by design

- **Data reading behind one function** (`read_data` in the project template).
  Today it reads CSV, Parquet and local Delta tables. Adding Fabric means one
  more branch in that function, not changes all over the code.
- **Model export after approval.** Once a version is approved, it is saved as a
  standard MLflow model folder (pyfunc flavor, input signature, pinned
  packages). The same folder can be registered in Azure ML or Fabric, or loaded
  on a laptop.
- **Estimated cost per run.** Every job logs its duration and an estimated cost
  (duration × the price per hour of the cluster's machine type) to MLflow. It is
  an estimate for comparing runs; the bill comes from Azure Cost Management,
  split per project by the cluster's tags.

## 5. Repos and templates

Four repos, each with an `AGENTS.md` for its users and their AI agents:

| Repo | Purpose | Steps | Users |
|---|---|---|---|
| `ml-requests` | Request form (GitHub issue) and process | 1-3 | Requesters, platform lead |
| `ml-infra-template` | Terraform modules `ml-workspace`, `ml-project` | 2-3 | Platform engineers |
| `cdp-ml-onboarding` | Example of the platform repo's ML registry: YAML files, their schema, and the Terraform that reads them | 2-3 | Platform team, platform lead |
| `ml-project-template` | Code template, one repo per use case | 4-5 | Model owner and team |

### 5.1 GitHub template repo (one repo per use case)

```
ml-project-template/
├── README.md, AGENTS.md       # how to use this repo, for people and AI agents
├── model-card.md              # owner, purpose, data version, metrics, approvals
├── config.yml                 # all settings
├── src/                       # prep, train, evaluate, register, score
├── jobs/                      # Azure ML job definitions: train-register, batch-score
├── environment/conda.yml      # Python packages the jobs need
├── notebooks/                 # optional: scoring in Fabric (option A)
├── tests/
└── .github/workflows/         # ci, train, deploy (waits for approval), score (nightly),
                               # review-reminder (quarterly), demo-local-flow (demo, no Azure)
```

| Part | Question it answers |
|---|---|
| `src/` | What runs |
| `environment/` | With which packages |
| `jobs/` | Where and how it runs (script, data, compute) |
| `.github/workflows/` | When it runs (on PR, on demand, after approval, nightly) |

Notes:
- Deployment uses a **GitHub environment with required reviewers**: that is the approval gate.
- Shared CI/CD logic should live in **one central repo of reusable workflows**,
  so improvements reach every project.
- GitHub authenticates to Azure with **OIDC** (federated credentials), no stored secrets.
  The project repo only knows the infrastructure by name, through GitHub variables:
  `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`,
  `AZURE_RESOURCE_GROUP`, `AZURE_ML_WORKSPACE`.
- The repo contains **no Terraform**: infrastructure exists before the project starts.

### 5.2 Terraform modules

`ml-workspace`, **once per project**, in the project's resource group: Azure ML
workspace with storage, key vault, container registry and Application Insights.

`ml-project`, **once per use case**. Nobody calls it by hand: the platform repo's
Terraform calls it once for every file in the ML registry. A use case is described
by one YAML file, checked against a JSON schema:

```yaml
# registry/ml_use_cases/manufacturing__tool-wear.yaml
schema_version: "1.0.0"
use_case_id: tool-wear
department: manufacturing
owner: "[owner]"
github_repo: "[org]/ml-tool-wear"
risk_tier: decision_support
gpu: false
reads:
  - manufacturing.gold.fact_machine_sensors
predictions_table: ml_tool_wear_predictions   # Gold table, `ml_` prefix
```

`ml-project-github`, **once per use case** (next to `ml-project`): the
project's GitHub repo from the template, its five Azure variables, the
approval-gated environment and the GitHub login rules. With it, one registry
YAML file is all a new project needs; nothing is copied by hand.

`ml-project` creates:
- a compute cluster for this use case (CPU by default, GPU if `gpu: true`),
  scaling to 0, running as the project's identity and tagged with the use case;
- an Entra ID group with a limited data-scientist role on the department's
  workspace (never Owner or Contributor);
- the project's identity, used by the cluster and by this repo's GitHub
  workflows (trusting only that repo);
- read access to the platform data, write access to the Gold `ml_` predictions
  table (placeholders until the Fabric side is clear);
- outputs: the IDs the project repo needs as GitHub variables.

GPU **quota** is a separate request to Microsoft; Terraform can only use it once granted.
The module's exact design must follow how the platform team already structures Terraform.

## 6. Roles

| Role | Responsibility |
|---|---|
| Requester | Brings the problem and how predictions would be used |
| Platform lead *(open)* | Qualifies requests, sets up projects, owns the templates |
| Data owners | Approve access to data domains |
| Model owner and team | Build, run and review the model |
| Reviewer *(open)* | Approves model versions at the gate |
| Platform team | Terraform, workspaces, security, capacity |

## 7. Out of scope for v1

- Infrastructure code inside project repos (the platform team provisions it).
- Online endpoints, automatic retraining on drift, feature store.
- More than two pipeline types (`train-register`, `batch-score`).
- A shared exploration workspace ("playground"): exploring happens locally.

## 8. Open questions

- Who is the platform lead, and who reviews at the approval gate?
- Does the Terraform module fit how the platform team structures its repo? If the
  platform already has a registry with a resolver (YAML → contract → Terraform), the
  ML registry files should become a new object type there.
- How do Azure ML and Fabric connect over the network? See section 9.
- Retirement criteria for models (e.g. no predictions consumed for X months).
- Which environments (dev/test/prod) are needed, and when? **Proposed default:
  one workspace per project, no separate environments.** Inside it, the approval
  gate (candidate → champion) already keeps untested models away from real predictions. Separate
  dev/prod workspaces stay optional, for platforms whose rules require them; the
  platform team decides.

## 9. Later: the Fabric connection (documented, not built)

The templates work end to end without Fabric (public data, a job output folder
for predictions). Connecting to Fabric is a later milestone, once the platform
team has decided on networking.

**Identity (approach already tested in a similar setup).** The compute
cluster's identity is added to a role on the Fabric lakehouse (or its
workspace). Jobs on that cluster can then read and write OneLake with a token
for that identity. With one cluster per project, each project only gets the
access granted to its own identity.

**Networking options** (the platform team decides):

| Option | How | Notes |
|---|---|---|
| Public endpoints | Jobs reach OneLake over its public address; access is decided by identity | Simplest; only possible if the Fabric tenant allows public access |
| Private endpoints | Azure ML's managed virtual network reaches Fabric through a private link | Needed if Fabric blocks public access; more setup, to verify which Fabric private link fits |
| Different regions | Azure ML and the Fabric capacity may sit in different Azure regions | Check data residency rules, latency and data transfer costs |

**What changes in the code:**
1. `read_data` gets a branch for OneLake table addresses (`abfss://…/Tables/…`),
   with a token for the job's identity; it logs the table's Delta version.
2. `write_predictions` uses the same token to write the Gold `ml_` table.
3. The job inputs point to the Gold tables instead of uploaded files.
4. `ml-project` grants the lakehouse role to the cluster's identity
   (today a placeholder: `data_access_todo`).

## 10. Build order for this workspace

All four repos are built in one workspace first, tested **locally on public
data** using the
[AI4I 2020 Predictive Maintenance dataset](https://archive.ics.uci.edu/dataset/601/ai4i+2020+predictive+maintenance+dataset)
(machine sensor data with failure labels):

1. Restructure into the four folders.
2. Project template: prep → train → evaluate → register → score, tracked with local MLflow.
3. Project template: Azure ML job definitions, environment, GitHub workflows.
4. Terraform modules (validated, not applied).
5. Platform repo onboarding example.
6. Request form and process.

Then, phase 2 (templates working end to end in a personal Azure ML sandbox):

7. Decisions in the docs (this section, cluster per project, setup at the end of step 3).
8. Data reading behind one function.
9. Model export after approval.
10. Estimated cost per run.
11. Terraform: one cluster per project, with its identity and tags.
12. End-to-end run in an Azure ML sandbox (CPU only, small quota).

## 11. References

- [Epiroc: steel quality with Azure Machine Learning](https://www.microsoft.com/en/customers/story/1653030140221000726-epiroc-manufacturing-azure-machine-learning)
- [Predict steel quality with Azure AutoML and ESML](https://techcommunity.microsoft.com/blog/azure-ai-foundry-blog/predict-steel-quality-with-azure-automl-in-manufacturing/3616176)
- [Enterprise Scale AI Factory (formerly ESML)](https://github.com/azure/enterprise-scale-aifactory)
- [Outokumpu: digital innovation hub and MLOps platform](https://www.solita.fi/work/outokumpu-digital-innovation-hub-drives-ai-solutions-in-sustainable-stainless-steel/)
- [Volkswagen and AWS: end-to-end MLOps](https://aws.amazon.com/blogs/industries/how-volkswagen-and-aws-built-end-end-mlops-for-digital-production-platform/)
- [Spotify: unleashing ML innovation with Ray](https://engineering.atspotify.com/2023/02/unleashing-ml-innovation-at-spotify-with-ray)
- [Set up MLOps with GitHub and Azure ML](https://learn.microsoft.com/en-us/azure/machine-learning/how-to-setup-mlops-github-azure-ml)
- [Azure MLOps v2 accelerator](https://github.com/Azure/mlops-v2)
- [Organize and set up Azure ML environments](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/ai-machine-learning-resource-organization)
- [Fabric: model scoring with PREDICT](https://learn.microsoft.com/fabric/data-science/model-scoring-predict)
