# Azure Production Terraform Stack

## Canonical Terraform root

The only active Terraform root in this repository is:

`infrastructure/terraform/environments/production`

Reusable modules live under:

`infrastructure/terraform/modules`

Do not run Terraform from the repository root. Obsolete root-level Terraform scaffolding has been removed so automation and operators cannot accidentally target a second architecture.

## Managed production architecture

The active stack currently manages:

- Azure Kubernetes Service (AKS)
- Azure Container Registry (ACR)
- Azure Key Vault
- PostgreSQL Flexible Server
- Azure Cache for Redis
- Private Endpoints and Private DNS

## Deployment flow

```text
Pull Request
    |
Terraform PR validation
    |
fmt + init(backend=false) + validate
    |
Merge to main
    |
Terraform Azure Apply
```

## Hardening validation

This commit retriggers the PR validation loop after workflow trigger hardening changes.

See `SECURITY.md` for the repository security policy.
