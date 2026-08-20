# Terraform Existing Resource Adoption Runbook

## Purpose

生产环境接入 Terraform 时，不允许通过 apply 重新创建已有 Azure 资源。

Terraform 的目标是接管生命周期，而不是替换现有基础设施。

## Standard Flow

```
Existing Azure Resource
        |
        v
terraform import
        |
        v
terraform plan
        |
        v
No unexpected destroy/replace
        |
        v
Terraform management
```

## Forbidden

不要直接修改资源名称：

```
old resource name
        |
terraform apply
        |
 destroy + create
```

## Migration

资源迁移必须使用：

- terraform import
- terraform state mv
- review terraform plan

## Production Checklist

- [ ] Azure resource inventory completed
- [ ] Terraform address defined
- [ ] Import executed
- [ ] Plan verified
- [ ] No destructive change
- [ ] Approval completed
