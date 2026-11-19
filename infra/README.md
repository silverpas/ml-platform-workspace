# `infra/`: cloud setup as code (Terraform)

Describes what Azure needs to give one ML use case, so the platform team can
set it up with one block of code instead of clicking in the portal.

| Folder | What it is |
|---|---|
| `modules/ml-project/` | The module: project identity, secret-free GitHub login, permission on the department workspace, compute cluster. See its [README](modules/ml-project/README.md) |
| `modules/ml-project/examples/basic/` | What the one block looks like |
| `modules/ml-project/tests/` | Tests against a fake Azure (`terraform test`) |

**Who uses it:** the platform team. They copy the module into their own
Terraform repo and run it there. Nothing in this template is ever applied, and
project teams don't need to change anything here.

**Not here:** the department's Azure ML workspace. The platform team creates it
once per department; this module only plugs a use case into it.
