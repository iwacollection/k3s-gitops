# Azure Production Terraform Controls

## Required Controls

### Terraform Layer

- prevent_destroy for critical resources
- plan destructive change detection
- state migration before rename

### Azure Layer

Critical resources should have:

- Resource Lock (CanNotDelete)
- RBAC least privilege
- Activity Log monitoring

## Protected Resources

- Resource Group
- Virtual Network
- Subnet
- AKS
- Storage Account
- Key Vault
- Managed Identity

## Rule

A production change must answer:

1. Is this a new resource?
2. Is this modifying an existing resource?
3. Will this replace the resource?
4. Is approval required?
