# CDP ML onboarding (example)

A simulated slice of the platform team's Terraform repo (CDP), showing exactly
what is added there for machine learning:

- **once per department**: one `ml-workspace` block (example: `manufacturing`);
- **once per ML use case**: one `ml-project` block (example: `tool-wear`),
  plus its outputs, which become the project repo's GitHub variables.

It is an example to copy from, not a replacement for the real repo.
The Terraform files and the onboarding checklist arrive in milestone 5.
See [AGENTS.md](AGENTS.md) for the workflow and rules.
