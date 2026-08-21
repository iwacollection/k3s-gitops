# Production Terraform Adoption Guide

## Goal

Existing Azure resources must be imported and managed without accidental recreation.

## Required flow

```text
Existing Azure Resource
        |
        v
terraform import
        |
        v
terraform plan
        |
        v
Adoption Safety Gate
        |
        v
terraform apply
```

## Production rules

- destroy actions must be zero
- replacement actions must be zero unless explicitly approved
- state changes require review
- resource locks must remain enabled on critical resources

## Protected resources

- AKS
- Virtual Network
- Subnet
- Key Vault
- Storage Account
- Managed Identity
