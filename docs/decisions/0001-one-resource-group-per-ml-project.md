# 0001: One resource group and one Azure ML workspace per ML project

- **Status:** accepted (2026-11-26). Replaces "one Azure ML workspace per department".
- **Affects:** `ml-infra-template`, `cdp-ml-onboarding`, `ml-requests`, design section 4.1.

## Context

The first version gave each **department** one shared Azure ML workspace, and
each ML project its own identity and cluster inside it. The platform team
prefers a stronger separation between projects.

## Decision

Every ML project gets **its own resource group**, `rg-ml-<department>-<use-case>`,
with everything it needs inside: the Azure ML workspace and its storage, key
vault, container registry and logs, plus the project's identity and cluster.
One registry YAML file per project creates all of it (and the project's GitHub
repo). The department stays as a tag and in names.

A project may also use an **existing** resource group (field `resource_group` in
its YAML file), for organizations where resource groups are created elsewhere.
Each project still needs a resource group of its own.

## Consequences

| | Better | Worse |
|---|---|---|
| Security | Each project is a separate unit: roles are given on its resource group; one project cannot see another's runs, models or files | |
| Costs | The resource group's bill is the project's cost | Fixed cost **per project** while it exists (container registry, storage, logs): about 5-10 EUR per month, even when idle |
| Life cycle | Retiring a project removes its resource group as a whole | |
| Sharing | | Models are not shared between projects by default; if needed later, an Azure ML *registry* shared by several workspaces |
| Operations | Simple to reason about: one project, one place | More workspaces to keep an eye on |

## Alternatives considered

- **One workspace per department** (the first version): cheaper and easier to
  share models, but projects share one workspace, so permissions and costs need
  more care. Still possible with the modules (`ml-workspace` is the same), but
  no longer the default.
- **Separate dev / test / prod workspaces per project**: optional through the
  modules' `environment` input; not the default, because the approval gate
  (candidate → champion) already keeps untested models out of use.
