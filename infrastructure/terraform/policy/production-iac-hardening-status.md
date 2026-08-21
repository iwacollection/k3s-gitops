# Production IaC Hardening Status

## Objective

将 Terraform 从资源创建脚本提升为生产级 Infrastructure Lifecycle Management（基础设施生命周期管理）平台。

## Mandatory Flow

```text
Pull Request
    |
    v
terraform fmt
    |
terraform validate
    |
terraform plan -out=tfplan
    |
terraform show -json
    |
Destroy / Replace Risk Check
    |
Approval
    |
terraform apply tfplan
```

## Existing Azure Resource Adoption

生产已有资源禁止直接 apply 创建。

流程：

```text
Azure Existing Resource
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
Terraform ownership
```

## Protected Resources

Critical resources require protection:

- Resource Group
- Virtual Network
- Subnet
- AKS
- Storage Account
- Key Vault
- Managed Identity

Recommended protection:

```hcl
lifecycle {
  prevent_destroy = true
}
```

and Azure Resource Lock:

```text
CanNotDelete
```

## Production Rule

禁止：

- 直接 terraform apply 生产
- 修改资源名称导致 replacement
- 手工修改 Terraform state
- 删除重建已有 Azure 资源
