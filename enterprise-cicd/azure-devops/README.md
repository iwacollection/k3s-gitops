# Azure DevOps Control Plane

Enterprise IaC and environment-governance control plane.

Responsibilities:
- Terraform Plan/Apply orchestration
- protected Environments and approvals/checks
- required templates and branch control
- service-connection authorization
- exclusive locks for environment mutation
- governed Agent/Runner pools

Application build logic stays in shared CI contracts/templates; production governance must not rely only on mutable pipeline YAML.
