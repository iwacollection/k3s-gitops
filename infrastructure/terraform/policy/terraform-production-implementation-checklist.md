# Terraform Production Implementation Checklist

## Change lifecycle

```
PR
 |
 v
terraform fmt
 |
v
terraform validate
 |
v
terraform plan -out=tfplan
 |
v
risk gate
 |
v
approval
 |
v
terraform apply tfplan
```

## Existing Azure resource adoption

Existing resources must be imported before management:

```
Azure Resource
    |
terraform import
    |
terraform plan
    |
No unexpected destroy
    |
Terraform ownership
```

## Forbidden operations

- Direct production apply from developer machines
- Recreating existing production resources
- Manual state modification
- Renaming critical resources without migration

## Critical resources

- Resource Group
- Virtual Network
- Subnet
- AKS
- Key Vault
- Storage Account
- Managed Identity

All critical resources require lifecycle protection and reviewed changes.
