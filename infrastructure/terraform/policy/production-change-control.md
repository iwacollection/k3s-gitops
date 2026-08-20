# Production Terraform Change Control

## Required flow

```text
Pull Request
    |
terraform fmt
    |
terraform validate
    |
terraform plan -out=tfplan
    |
Risk checks
    |
Human approval
    |
terraform apply tfplan
```

## Forbidden production operations

- Direct apply from developer workstation
- Recreating existing resources to fix drift
- Editing terraform state manually
- Renaming critical resources without migration

## Existing Azure resource adoption

```text
Azure Resource
      |
terraform import
      |
terraform plan
      |
verify no destroy
      |
managed by Terraform
```

## Critical resources

Require additional review:

- Resource Group
- Virtual Network
- Subnet
- AKS
- Storage Account
- Key Vault
- Identity
