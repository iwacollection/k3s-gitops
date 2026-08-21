# Azure Terraform Backend Standard

## Purpose

生产环境 Terraform 必须使用 Azure Storage Remote Backend。

## Requirements

- remote state storage
- state lock
- state versioning
- state backup
- environment isolation

## Production Flow

```text
Developer
   |
terraform plan
   |
Remote Backend Lock
   |
Review
   |
approved apply
```

## Rules

- 禁止本地 state 作为生产状态源
- 禁止多人同时 apply
- backend migration 必须经过 review
- state 变更必须可审计
