# Terraform Production Module Standards

## Goals

All Azure Terraform modules must support:

- Existing resource adoption
- Safe lifecycle management
- Standard naming
- Required tagging
- Monitoring integration
- Production review workflow

## Module Structure

```
module/
├── main.tf
├── variables.tf
├── outputs.tf
├── lifecycle.tf
├── versions.tf
└── README.md
```

## Production Rules

1. Existing Azure resources must be imported before management.
2. Terraform plan must not contain unexpected destroy/replace operations.
3. Production resources should enable lifecycle protection where appropriate.
4. All modules must expose predictable inputs and outputs.
