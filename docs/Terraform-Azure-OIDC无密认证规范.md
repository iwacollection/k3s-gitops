# Terraform Azure OIDC无密认证规范

## 目标

GitHub Actions执行Terraform时，不再使用长期保存的 Azure Service Principal Secret。

认证链路：

GitHub Actions

↓

OIDC Token

↓

Azure Entra ID Federated Credential（工作负载联合身份）

↓

Azure Managed Identity / Service Principal

↓

Terraform Provider Azure

## 管理原则

禁止：

- 在GitHub Secrets保存长期Azure Client Secret
- 多环境共享同一个认证身份
- 使用管理员权限执行Terraform

要求：

- 最小权限RBAC
- dev/staging/prod身份隔离
- 生产环境必须审批后Apply

## 权限建议

Terraform Plan：

- Reader
- Resource Group Reader

Terraform Apply：

- Contributor（限制Scope）

高风险资源：

- AKS
- Network
- Key Vault

需要额外审批。