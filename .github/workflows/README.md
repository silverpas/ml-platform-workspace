# `.github/workflows/`: automation

Workflows are recipes GitHub runs by itself, on its own computers, when
something happens (a push, a button click, a schedule). See them run in the
repo's **Actions** tab.

| File | Starts when | What it does | Needs Azure? |
|---|---|---|---|
| `ci.yml` | Every push and pull request | Runs ruff, pytest and the Terraform tests; ✅ or ❌ on the commit | No |
| `demo.yml` | "Run workflow" button, or a push that changes `src/`, `config.yml` or `requirements.txt` | The full flow on GitHub's computers: train → **approval** → score | No |
| `train.yml` | *coming later* | Same as the demo's train step, but runs in Azure ML | Yes |
| `deploy.yml` | *coming later* | Same as the demo's approve + score step, but in Azure ML, writing to Fabric | Yes |

## The approval gate

The `deploy` step uses a GitHub **environment** (`approval-demo` now, `production`
later) with **required reviewers**. GitHub pauses the run there and shows a
**Review deployments** button to the reviewers. Nothing is promoted until one
of them approves.

Set it up once under *Settings → Environments*. On private repositories this
feature needs a paid GitHub plan; on public ones it is free.

**For a new use case:** nothing to change here. Add your reviewers to the
environment.
