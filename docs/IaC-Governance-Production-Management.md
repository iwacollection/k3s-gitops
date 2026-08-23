# 企业级 IaC（基础设施即代码）生产治理规范

> 本文用于说明企业生产环境如何管理 Terraform、如何接管已有 Azure 资源、如何通过权限和流程避免误删除、误重建、错误发布。

---

# 一、IaC 管理核心原则

## 1. 为什么使用 IaC

生产环境基础设施不能依赖人工操作。

传统方式：

```
工程师
  |
  v
Azure Portal 手工修改
  |
  v
资源状态不可追踪
```

问题：

- 谁修改不知道
- 为什么修改不知道
- 修改无法审计
- 容易产生配置漂移
- 无法快速恢复

IaC 模式：

```
代码仓库
    |
    v
Pull Request
    |
    v
CI检查
    |
    v
Terraform Plan
    |
    v
审批
    |
    v
Apply
```

所有生产变更必须经过代码审查。

---

# 二、生产 IaC 管理模型

## 1. 仓库结构

推荐结构：

```
infrastructure/
│
├── terraform/
│   │
│   ├── modules/
│   │   ├── network
│   │   ├── aks
│   │   ├── database
│   │   ├── key-vault
│   │   └── monitoring
│   │
│   └── environments/
│       ├── dev
│       ├── staging
│       └── production
│
└── kubernetes/
```

---

## 2. Module 管理原则

Module（Terraform 模块）：负责封装资源能力。

例如：

```
network module

负责:
- VNET
- subnet
- route table
- NSG
```

Module 不保存环境配置。

禁止：

```
modules/network/
    production cidr
    production password
```

原因：

模块应该可以复用。

---

## 3. Environment 管理原则

Environment（环境层）：保存环境差异。

例如：

```
production/

region = eastasia
aks_node_count = 5
sku = premium
```

负责：

- 生产参数
- 网络规划
- 容量配置
- Feature 开关

---

# 三、生产变更标准流程

任何生产资源变更：

```
需求
 |
 v
修改 Terraform
 |
 v
Pull Request
 |
 v
CI检查
 |
 +-- terraform fmt
 +-- terraform validate
 +-- tflint
 +-- checkov
 +-- policy check
 |
 v
Terraform Plan
 |
 v
人工审核
 |
 v
Terraform Apply
 |
 v
验证
```

禁止：

- 本地直接 apply
- Portal 修改生产
- 绕过审批

---

# 四、已有 Azure 资源如何接入 Terraform

## 目标

不是重新创建资源。

目标状态：

```
Azure Existing Resource
          |
          v
Terraform State
          |
          v
Terraform 管理
```

---

# 接入步骤

## Step 1：资源盘点

首先扫描 Azure：

```
az resource list
az aks list
az network vnet list
az postgres flexible-server list
```

形成资产表：

|资源|Resource ID|Terraform模块|
|-|-|-|
|VNET|xxx|network|
|AKS|xxx|aks|
|Database|xxx|database|

---

## Step 2：编写 Terraform 定义

例如已有 AKS：

```hcl
resource "azurerm_kubernetes_cluster" "main" {
}
```

注意：

这里只描述资源。

不能直接创建。

---

## Step 3：导入 State

使用：

```bash
terraform import \
azurerm_kubernetes_cluster.main \
/resource/id
```

效果：

```
Azure资源
   |
   v
Terraform State
```

---

## Step 4：Plan 校准

执行：

```bash
terraform plan
```

理想结果：

```
No changes
```

如果出现：

```
-/+ recreate
- destroy
```

禁止执行。

需要分析：

- Terraform 缺少属性
- Azure 默认配置
- 人工修改漂移
- Provider版本变化

---

# 五、如何防止错误删除和错误重建

这是生产 IaC 最重要部分。

## 1. Terraform State保护

生产禁止：

```
terraform.tfstate 本地保存
```

使用：

```
Azure Storage Backend
        |
        +-- State Lock
        +-- Version History
        +-- Backup
```

作用：

避免多人同时修改导致状态损坏。

---

## 2. prevent_destroy保护

核心资源：

- AKS
- Database
- Key Vault
- Network

增加：

```hcl
lifecycle {
  prevent_destroy = true
}
```

效果：

即使误执行：

```
terraform destroy
```

Terraform 会阻止。

---

## 3. Plan风险检测

Apply之前必须检查：

```
terraform plan
```

关注：

创建：

```
+ create
```

修改：

```
~ update
```

删除：

```
- destroy
```

高风险：

```
destroy database
replace AKS
replace network
```

必须人工审批。

---

# 六、权限治理设计

## Developer权限

开发人员：

允许：

- 提交代码
- 创建PR
- 查看资源

禁止：

- terraform apply
- 删除生产资源
- 修改生产Portal资源

---

## CI/CD权限

采用：

Azure OIDC（无长期密钥身份认证）

流程：

```
GitHub Actions
       |
       v
OIDC Token
       |
       v
Azure Identity
       |
       v
Terraform Apply
```

优势：

- 无Access Key
- 权限可审计
- 自动过期

---

## Production Approval

生产Apply必须：

```
Terraform Plan
       |
       v
人工审批
       |
       v
Apply
```

审批角色：

- SRE
- Cloud Owner
- 系统负责人

---

# 七、安全治理 Policy as Code

Policy as Code（策略即代码）：

在CI阶段自动阻止风险配置。

禁止：

```
公网数据库

公网Key Vault

开放全部端口Security Group

未加密存储
```

流程：

```
Terraform Plan
       |
       v
JSON Plan
       |
       v
OPA Policy
       |
       v
Allow / Reject
```

---

# 八、生产故障恢复

## Terraform State损坏

流程：

```
恢复Storage版本
        |
        v
检查State
        |
        v
terraform plan
        |
        v
恢复管理
```

---

## 资源漂移

Drift Detection（漂移检测）：

定期执行：

```
terraform plan
```

发现：

```
Azure实际状态
        !=
Terraform代码状态
```

需要：

- 修改代码
或者
- import重新接管

---

# 九、企业最终治理目标

最终形成：

```
需求
 |
 v
Git PR
 |
 v
IaC Review
 |
 v
Security Gate
 |
 v
Terraform Plan
 |
 v
Approval
 |
 v
Apply
 |
 v
验证
 |
 v
CMDB同步
```

达到：

- 所有资源代码化
- 所有变更可审计
- 所有权限最小化
- 所有危险操作可阻断
- 生产环境不会因为误操作重建或删除
