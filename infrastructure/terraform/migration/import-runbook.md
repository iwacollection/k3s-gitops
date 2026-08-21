# Existing Azure Resource Import Runbook

## Goal

已有 Azure 资源接入 Terraform 时，不允许删除重建。

## Process

```text
Existing Azure Resource
        |
terraform import
        |
terraform plan
        |
Review diff
        |
Apply
```

## Safety Rules

Before apply:

- create = expected
- destroy = 0
- replace = 0

Any unexpected replacement requires manual approval.

## Production Principle

Terraform should become the owner of existing resources gradually, not recreate production infrastructure.
