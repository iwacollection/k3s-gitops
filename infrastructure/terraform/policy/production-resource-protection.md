# Production Resource Protection

## Critical Azure resources

Protect with Terraform lifecycle controls:

- Resource Group
- Virtual Network
- Subnet
- AKS
- Storage Account
- Key Vault
- Managed Identity

Recommended:

```hcl
lifecycle {
  prevent_destroy = true
}
```

## Change policy

Allowed automatically:

- tags
- monitoring configuration
- non destructive metadata

Require approval:

- delete
- replace
- network CIDR changes
- identity permission changes
- AKS topology changes

Existing resources must follow import-first adoption.
