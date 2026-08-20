# Terraform Resource Lifecycle Policy

## Production rules

1. Existing Azure resources must be imported before management.
2. Resource names are immutable identifiers. Renaming requires state migration.
3. Critical resources must use lifecycle protection:

```hcl
lifecycle {
  prevent_destroy = true
}
```

Protected resources:

- Resource Group
- Virtual Network
- Subnet
- AKS Cluster
- Storage Account
- Key Vault
- Managed Identity

## Forbidden workflow

```text
change resource name
        |
terraform apply
        |
destroy/create
```

## Required workflow

```text
resource migration
        |
terraform state mv or import
        |
terraform plan
        |
review
        |
apply
```
