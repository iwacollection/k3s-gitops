# Critical Azure Resource Protection

## Protected resources

- Resource Group
- Virtual Network
- Subnet
- AKS Cluster
- Storage Account
- Key Vault
- Managed Identity

## Terraform protection

Critical resources should use:

```hcl
lifecycle {
  prevent_destroy = true
}
```

## Azure protection

Use Azure Resource Lock where deletion risk is unacceptable.

## Change rule

Rename or replacement changes require migration:

```
terraform state mv
or
terraform import
```

Never rely on destroy/create for production adoption.
