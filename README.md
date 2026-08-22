# Azure Production Terraform Stack

## Active stack

The production entrypoint used by GitHub Actions is:

`infrastructure/terraform/environments/production`

Reusable modules live under:

`infrastructure/terraform/modules`

The root-level Terraform files are an earlier architecture scaffold and are not used by the production Plan/Apply workflows.

## Managed production architecture

The active stack manages and verifies:

- Azure Load Balancer + Public IP
- PostgreSQL Flexible Server
- Azure Cache for Redis
- Virtual Network
  - AKS subnet
  - Private-endpoint subnet reserved for later private connectivity
- Network Security Group
- NAT Gateway + Public IP
- Azure Kubernetes Service (AKS)
  - Azure CNI
  - OIDC issuer
  - Workload Identity
  - Log Analytics / Container Insights integration
- Azure Container Registry (ACR)
- Azure Key Vault
- Log Analytics Workspace

PostgreSQL is intentionally deployed in East US 2 because the current subscription is restricted from provisioning PostgreSQL Flexible Server in East US. The remaining production foundation is deployed in East US.

## Deployment flow

```text
Pull Request
    |
Terraform Azure Plan
    |
fmt + init + validate + plan
    |
Merge to main
    |
Terraform Azure Apply
    |
Azure OIDC Apply Identity
    |
Remote AzureRM state + state lock
    |
terraform plan
    |
terraform apply
    |
Azure CLI live resource verification
    |
Issue #22 Apply Tracker
```

Production rules:

- Remote state only for Apply.
- No direct production Apply from a developer workstation.
- Existing managed resources are refreshed from remote state before changes.
- Destructive or replacement changes must be reviewed in Plan before merge.
- Apply completes only after Azure API verification confirms the expected resources exist.
