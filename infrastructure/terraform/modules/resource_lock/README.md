# Terraform Resource Lock Module

## Purpose

Protect production Azure resources from accidental deletion.

## Protection model

```
Terraform lifecycle prevent_destroy
        +
Azure Management Lock (CanNotDelete)
        =
Production resource protection
```

## Usage

```hcl
module "resource_lock" {
  source = "../../modules/resource_lock"

  resource_id = azurerm_resource_group.main.id
  lock_name   = "production-resource-protection"
  lock_level  = "CanNotDelete"
}
```

## Production rule

Critical resources should enable:

- AKS
- VNet
- Subnet
- Key Vault
- Storage Account
- Managed Identity

Do not remove locks during normal changes. Removal requires explicit production approval.
