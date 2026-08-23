# Terraform 生产级 Module 审计规范

## 目标

保证 Terraform Module 可以安全管理生产 Azure 资源，避免误创建、误删除和不可控变更。

## 审计内容

### 1. Module边界

一个 Module 只负责一种基础设施能力。

示例：

- network：VNet、Subnet、Route、NSG
- aks：AKS集群、Node Pool、Identity
- acr：Azure Container Registry
- monitoring：监控基础组件

禁止业务应用资源进入基础设施 Module。

## 2. 代码规范

每个 Module 必须包含：

- main.tf
- variables.tf
- outputs.tf
- versions.tf

禁止：

- 硬编码Subscription
- 明文Secret
- 环境参数写死
- 隐式依赖

## 3. 生产变更检查

重点检查：

- destroy
- replace
- force new resource
- lifecycle变化

任何生产资源重建必须人工审核。
