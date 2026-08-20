# Terraform Existing Resource Adoption Checklist

## Purpose

用于将已有 Azure 资源安全接入 Terraform 管理。

禁止流程：

```
写 Terraform
    |
    v
terraform apply
    |
    v
尝试覆盖已有资源
```

正确流程：

```
Azure Existing Resource
        |
        v
terraform import
        |
        v
terraform plan
        |
        v
No destroy/create
        |
        v
正式纳管
```

## Checklist

- [ ] 确认 Azure 资源真实存在
- [ ] 确认 Terraform resource address
- [ ] 执行 terraform import
- [ ] terraform plan 必须无 destroy
- [ ] 检查 state 与 Azure 实际一致
- [ ] 资源命名变更必须使用 state migration

## 禁止操作

不要直接修改：

- resource name
- resource group name
- VNet name
- subnet name

如果必须变更，需要：

- terraform state mv
- terraform import
- migration plan
