# Existing Azure Resource Adoption Workflow

## Goal

Adopt existing Azure resources into Terraform without deleting and recreating resources.

## Production Flow

```text
Azure Existing Resource
        |
        v
Discovery
        |
        v
Resource Mapping Validation
        |
        v
terraform import
        |
        v
terraform plan
        |
        +--> destroy/replace detected -> stop
        |
        v
Approved apply
```

## Rules

- Never recreate existing production resources only to make Terraform manage them.
- Import first, plan second.
- Any destroy or replacement requires explicit review.
- Keep Terraform state as the source of management truth after adoption.
