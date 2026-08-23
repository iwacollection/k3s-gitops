# Enterprise IaC Governance and Production Management Guide

## 1. 当前 IaC 仓库审核

当前仓库已经具备基础企业化结构：

```
.
├── infrastructure
│   └── terraform
│       ├── environments
│       └── modules
├── kubernetes
├── helm
└── .github/workflows
```

Terraform 已按照：

```
Environment Layer
        |
        v
Root Module
        |
        v
Reusable Modules
        |
        v
Azure Resources
```

进行拆分。

现阶段能力：

|能力|状态|
|-|-|
|Terraform Modules|已有|
|Environment 隔离|已有|
|CI Pipeline|已有基础|
|Security Scan|已有建设|
|Plan Gate|建设中|
|Apply Governance|需要完善|
|Existing Resource Import流程|需要补齐|

---

# 2. 企业生产环境 IaC 管理方式

## 核心原则

生产环境禁止：

- 人工 Azure Portal 修改生产资源
- 开发人员直接执行 terraform apply
- 修改 Terraform 后直接覆盖生产
- 删除 resource block 后直接 apply

生产唯一入口：

```
Developer
    |
    v
Pull Request
    |
    v
CI Validation
    |
    +-- terraform fmt
    +-- validate
    +-- tflint
    +-- checkov
    +-- security policy
    |
    v
Terraform Plan
    |
    v
Approval
    |
    v
Terraform Apply
```

---

# 3. Terraform 分层设计

## Module 层

负责资源能力封装：

例如：

```
modules/
├── network
├── aks
├── database
├── key-vault
├── container-registry
└── monitoring
```

Module 不保存环境配置。

---

## Environment 层

负责生产参数：

```
environments/
├── dev
├── staging
└── production
```

保存：

- region
- SKU
- capacity
- network CIDR
- feature flags

---

# 4. 已有 Azure 资源接入 Terraform

## 目标

将：

```
Azure Existing Resources
        |
        v
Terraform State
        |
        v
Terraform Management
```

而不是重新创建。

---

## Step 1: 资源盘点

收集：

```
az resource list
az network vnet list
az aks list
az postgres server list
```

输出资产清单：

|资源|Resource ID|Terraform Module|
|-|-|-|
|VNET|xxx|network|
|AKS|xxx|aks|
|Postgres|xxx|database|

---

## Step 2: 编写 Terraform Resource 定义

例如已有 AKS：

```
resource "azurerm_kubernetes_cluster" "main" {
}
```

注意：

只定义资源，不创建。

---

## Step 3: Import State

执行：

```
terraform import \
azurerm_kubernetes_cluster.main \
/subscriptions/.../managedClusters/prod-aks
```

结果：

```
Azure Resource
      |
      v
Terraform State
```

---

## Step 4: Terraform Plan 校准

第一次：

```
terraform plan
```

目标：

```
No changes
```

如果出现 diff：

分析：

- Terraform 缺属性
- Azure 默认值
- 手工漂移

禁止直接 apply。

---

# 5. 防止错误重建、错误删除

## Resource Lifecycle Protection

关键资源：

```
AKS
Database
Key Vault
Network
```

增加：

```hcl
lifecycle {
  prevent_destroy = true
}
```

效果：

```
terraform destroy
        |
        X
blocked
```

---

# 6. State 管理

生产禁止 local state。

使用：

```
Azure Storage Account
        |
        v
Terraform Remote Backend
```

配置：

```
backend "azurerm" {
 storage_account_name = "xxx"
 container_name       = "terraform"
 key                  = "production.tfstate"
}
```

开启：

- state lock
- versioning
- backup

---

# 7. 权限控制模型

## Developer

权限：

```
Reader
```

只能：

- 提交代码
- 查看资源

不能：

- apply
- delete

---

## CI Pipeline Identity

使用：

```
Azure OIDC
```

权限：

```
Contributor
```

但限制：

- 只能 Terraform Runner 使用
- 无长期 Access Key

---

## Production Approval

流程：

```
Plan
 |
 v
Manual Approval
 |
 v
Apply
```

审批人：

- SRE
- Cloud Owner

---

# 8. 防止错误变更

## Terraform Plan Review

PR 必须展示：

```
Resources:
 + create
 ~ update
 - destroy
```

高风险：

```
- destroy database
- replace AKS
- replace network
```

自动阻断。

---

## Policy as Code

使用：

```
OPA / Conftest
```

禁止：

```
public database
public key vault
open security group
no encryption
```

---

# 9. 生产发布标准流程

```
Change Request
        |
        v
Git PR
        |
        v
CI Security Gate
        |
        v
Terraform Plan
        |
        v
Risk Review
        |
        v
Approval
        |
        v
Apply
        |
        v
Verification
        |
        v
CMDB Update
```

---

# 10. 后续完善项

- Terraform Cloud/Enterprise 或 Azure DevOps Backend
- Drift Detection Daily Job
- Cost Policy
- Resource Naming Policy
- CMDB 自动同步
- Disaster Recovery Validation
