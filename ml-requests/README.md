# ML requests

The front door for new machine learning use cases.

**Have an idea?** *Issues → New issue → ML project request.* Fill in the
problem, how the predictions will be used and the data you need. The platform
lead qualifies it with you and answers: approved, deferred or declined.

An approved request becomes one YAML file in the platform repo's ML registry.
From that file the project gets its own resource group on Azure (with its own
Azure ML workspace) and its own repo from the template. The form uses the same
field names as the YAML file, so nothing has to be asked twice.

Later the form moves to the company's service portal; the questions stay the same.

- How it works, step by step: [docs/process.md](docs/process.md)
- For the platform lead: [docs/qualify-checklist.md](docs/qualify-checklist.md),
  [docs/setup-checklist.md](docs/setup-checklist.md)
- Workflow, labels and rules: [AGENTS.md](AGENTS.md)
