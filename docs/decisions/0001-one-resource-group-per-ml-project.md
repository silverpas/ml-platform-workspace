# 0001: One resource group and one Azure ML workspace per ML project

- **Status:** accepted (2026-11-26)
- **Affects:** `ml-infra-template`, `cdp-ml-onboarding`, `ml-requests`, design section 4.1

## Decision

Every ML project gets **its own resource group**, `rg-ml-<department>-<use-case>`,
created by the platform from the project's registry YAML file. Inside it is
everything the project needs:

- its own **Azure ML workspace**, with storage, key vault, container registry
  and logs;
- the project's **identity** (the account its cluster and GitHub workflows use)
  and its **compute cluster**.

The same YAML file also creates the project's **GitHub repo** from the
template, with its variables, approval gate and login rules. The department is
used in names and tags.

## Why

- **Separation:** each project is a unit of its own. Roles are given on its
  resource group; one project cannot see another's runs, models or files.
- **Costs:** the resource group's bill is the project's cost.
- **Life cycle:** retiring a project removes its resource group as a whole.
- **Simple to explain:** one project, one place.

## Consequences

- A small **fixed cost per project** while it exists (container registry,
  storage, logs): about 5-10 EUR per month, plus the cluster only while it runs.
- Models are not shared between projects. If that is needed later, an Azure ML
  *registry* shared by several workspaces can be added.
- More workspaces to keep an eye on; the registry YAML files are the list.
