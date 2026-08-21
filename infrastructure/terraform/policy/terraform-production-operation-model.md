# Terraform Production Operation Model

## Production change flow

```
Pull Request
    |
    v
terraform fmt / validate
    |
    v
terraform plan -out=tfplan
    |
    v
terraform show -json tfplan
    |
    v
Risk Gate
    |
    v
Production Approval
    |
    v
terraform apply tfplan
```

## Existing Azure resource adoption

Production resources must follow:

```
Azure Resource
    |
    v
terraform import
    |
    v
terraform plan
    |
    v
No unexpected destroy/replace
    |
    v
Terraform ownership
```

## Forbidden operations

- Direct production terraform apply from developer workstation
- Recreating existing resources to solve state drift
- Manual state editing without recovery plan
- Renaming critical resources without migration

## Critical resources

- Resource Group
- Virtual Network
- Subnet
- AKS
- Key Vault
- Storage Account
- Managed Identity

These resources require lifecycle protection and reviewed changes.
