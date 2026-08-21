# Azure Production Terraform Stack

## Purpose

Create the production Azure foundation through Terraform.

## Target Architecture

- Resource Group
- VNet / Subnet
- NSG
- NAT Gateway
- AKS
- ACR
- Load Balancer / Application Gateway
- PostgreSQL Flexible Server
- Key Vault
- Monitoring

## Deployment Flow

```
GitHub Actions
    |
Azure OIDC
    |
terraform init
    |
terraform plan
    |
Risk Gate
    |
Approval
    |
terraform apply approved plan
    |
Verification
```

Production rules:

- Remote state only
- No direct apply from developer workstation
- Destroy and replace require review
- Existing resources must be imported before management
