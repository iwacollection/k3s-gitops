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
  - Azure CNI
  - multi-zone system and workload node pools
  - OIDC issuer and Workload Identity
  - Container Insights / Log Analytics integration
- Virtual Network
  - AKS subnet
  - dedicated Private Endpoint subnet
- Network Security Group
- NAT Gateway + Public IP
- Azure Container Registry (ACR)
- Azure Key Vault
- PostgreSQL Flexible Server
- Azure Cache for Redis
- Private Endpoints and Private DNS for ACR, Key Vault, PostgreSQL and Redis
- Azure Load Balancer + Public IP
- Log Analytics and diagnostic settings
- Azure Monitor activity-log alerting
- Defender for Containers and Defender for Key Vault
- Azure Policy for production tagging
- Resource-group budget controls
- Data Protection Backup Vault

PostgreSQL is intentionally deployed in East US 2 because this subscription has previously been unable to provision the selected PostgreSQL Flexible Server capability in East US. The remaining production foundation is deployed in East US.

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
    |
Azure OIDC identities
    |
Remote AzureRM state + state lock
    |
authoritative terraform plan
    |
0-destroy safety gate
    |
terraform apply
    |
Azure API / Kubernetes live verification
    |
Issue #22 Apply Tracker
```

### Important safety boundary

A PR job initialized with `-backend=false` does not read production state and therefore must not be treated as an authoritative production plan. The authoritative plan is the remote-state plan generated immediately before production Apply. The PR workflow is being hardened to remain credential-free and validation-only unless a trusted remote-state planning path is explicitly introduced.

## Production rules

- Use remote state for every production mutation.
- Do not run direct production Apply from a developer workstation.
- Use GitHub OIDC/workload federation instead of long-lived Azure client secrets.
- Never commit Terraform state, saved plans, generated backend files, kubeconfigs, private keys, real secret-bearing `tfvars`, or local credential files.
- Do not merge resource changes based only on a backend-disabled plan.
- The Apply workflow must reject unexpected delete/replacement actions before mutation.
- Do not weaken availability or security controls just to make convergence succeed.
- Irreversible security settings require a dedicated migration decision and rollback analysis.
- Apply is complete only after live Azure/Kubernetes verification passes and the tracker records the outcome.

## Hardening validation

This commit exists only to trigger the PR validation loop after workflow trigger hardening changes.

See `SECURITY.md` for the repository security policy.
