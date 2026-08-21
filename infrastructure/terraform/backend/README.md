# Terraform Backend Production Baseline

## Purpose

Production Terraform state must be treated as critical infrastructure.

## Requirements

- Remote backend only
- State locking enabled
- State versioning enabled
- State backup enabled
- Separate state per environment

## Azure Storage Backend Standard

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "<tfstate-rg>"
    storage_account_name = "<tfstate-storage>"
    container_name       = "tfstate"
    key                  = "production/platform.tfstate"
  }
}
```

## Migration Rules

Before changing backend:

1. Backup current state
2. Run `terraform init -migrate-state`
3. Verify state resources
4. Execute plan validation

Never delete or recreate backend storage during normal resource lifecycle operations.
