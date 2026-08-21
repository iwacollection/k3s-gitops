# Azure Terraform Resource Adoption

## Purpose

用于生产环境接管已有 Azure 资源，禁止通过 Terraform 删除旧资源重新创建。

## Workflow

```text
Azure Existing Resource
        |
        v
Resource Inventory
        |
        v
Terraform Mapping
        |
        v
terraform import
        |
        v
terraform plan
        |
        v
Destroy / Replace Check
        |
        v
Approval
        |
        v
Apply
```

## Production Rules

- Existing resources MUST be imported before management.
- Destroy actions require explicit review.
- Replace actions require explicit review.
- Import must be followed by terraform plan validation.
