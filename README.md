# Azure 生产环境 Terraform IaC 管理规范

## 1. 项目定位

本仓库是 Azure 生产环境基础设施即代码（IaC, Infrastructure as Code）的统一管理入口。

核心目标：

- 所有生产基础设施必须通过 Terraform 管理
- 所有变更必须经过代码审查和自动化安全检查
- 禁止人工直接修改生产资源导致漂移
- 防止错误创建、错误删除、错误重建生产资源

Terraform 根目录：

```
infrastructure/terraform/environments/production
```

公共模块目录：

```
infrastructure/terraform/modules
```

仓库采用：

```
Environment
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

不要在仓库根目录执行 Terraform。

当前 Terraform 结构：

```
infrastructure/terraform
│
├── environments
│   └── production
│       └── 生产环境入口
│
└── modules
    ├── aks
    ├── network
    ├── database
    ├── security
    └── monitoring
```

---

# 2. 当前管理的 Azure 资源

生产环境目前覆盖：

## Kubernetes 平台

- Azure Kubernetes Service (AKS)
- Azure CNI 网络模型
- 多可用区 Node Pool
- OIDC Issuer
- Workload Identity
- Container Insights

## 网络基础设施

- Virtual Network
- Subnet
- Network Security Group
- NAT Gateway
- Public IP
- Load Balancer

## 数据服务

- PostgreSQL Flexible Server
- Azure Cache for Redis
- Azure Container Registry

## 安全能力

- Azure Key Vault
- Private Endpoint
- Private DNS Zone
- Defender for Cloud
- Azure Policy

## 可观测性

- Log Analytics
- Diagnostic Settings
- Azure Monitor Alert

---

# 3. Terraform 生产变更流程

生产禁止：

```
开发人员电脑
      |
      X
terraform apply
```

标准流程：

```
开发修改 Terraform
        |
        v
创建 Pull Request
        |
        v
CI 自动检查
        |
        +-- terraform fmt
        |
        +-- terraform validate
        |
        +-- TFLint
        |
        +-- Checkov 安全扫描
        |
        +-- Policy as Code
        |
        v
Terraform Plan Review
        |
        v
人工审批
        |
        v
GitHub Actions Apply
        |
        v
Azure OIDC 身份认证
        |
        v
Terraform Apply
        |
        v
Azure/Kubernetes 验证
```

---

# 4. 如何接入已有 Azure 资源

已有资源不能直接重新创建，必须采用 Import 接管。

## Step 1：资源盘点

首先获取 Azure 当前资源：

```bash
az resource list
az aks list
az network vnet list
az postgres flexible-server list
```

形成资源清单：

```
资源名称
资源类型
Resource ID
当前配置
所属环境
```

---

## Step 2：编写 Terraform Resource

先定义 Terraform 配置：

```hcl
resource "azurerm_xxx" "production" {

}
```

注意：

这里不会创建资源，只是声明 Terraform 管理模型。

---

## Step 3：导入 State

执行：

```bash
terraform import RESOURCE RESOURCE_ID
```

例如：

```bash
terraform import azurerm_kubernetes_cluster.main \
/subscriptions/xxx/resourceGroups/prod/providers/Microsoft.ContainerService/managedClusters/prod-aks
```

完成：

```
Azure Existing Resource
          |
          v
Terraform State
          |
          v
Terraform Managed
```

---

## Step 4：第一次 Plan 校准

目标：

```
terraform plan

No changes
```

如果出现：

```
-/+ recreate
- destroy
+ create
```

禁止直接 Apply。

必须分析：

- Terraform 配置是否完整
- Resource ID 是否正确
- Provider 参数是否匹配
- 是否存在不可恢复变化

---

# 5. 权限治理设计

生产 IaC 使用最小权限原则。

## 开发人员

权限：

```
GitHub Repository Write
Azure Reader
```

允许：

- 修改 Terraform
- 创建 PR
- 查看资源

禁止：

- Terraform Apply
- 删除生产资源

---

## GitHub Actions

采用：

```
Azure OIDC Workload Identity
```

禁止：

- 长期 Azure Secret
- Access Key
- 本地账号认证

---

## Production Apply

必须经过：

```
Plan
 |
 v
审批
 |
 v
Apply
```

---

# 6. 防止错误删除和错误重建

## Terraform State 管理

生产必须使用：

```
Azure Storage Backend
        +
State Lock
        +
Version History
```

禁止：

```
local terraform.tfstate
```

---

## Destroy 防护

核心资源增加：

```hcl
lifecycle {
  prevent_destroy = true
}
```

保护：

- AKS
- PostgreSQL
- Key Vault
- Network
- Redis

---

## Plan 安全检查

Apply 前自动检查：

禁止：

```
Destroy > 0

Replace Critical Resource

Public Exposure

Security Downgrade
```

例如：

```
terraform plan
        |
        v
terraform show -json
        |
        v
Policy Engine
        |
        v
Allow / Reject
```

---

# 7. Drift Detection（配置漂移检测）

生产资源禁止手工修改。

定期执行：

```
terraform plan
```

发现：

```
Azure 实际状态
        !=
Git Terraform 状态
```

进入治理流程。

---

# 8. 安全 Gate

生产发布必须通过：

```
terraform fmt
        |
terraform validate
        |
TFLint
        |
Checkov
        |
Terraform Plan
        |
OPA Policy
        |
Approval
        |
Apply
```

禁止绕过安全检查。

---

# 9. 生产运维原则

- Terraform 是生产基础设施唯一事实来源
- Git 是变更审计记录
- State 是资源生命周期管理依据
- Plan 是变更风险评估依据
- Approval 是生产保护边界
- Apply 后必须验证 Azure/Kubernetes 状态

---

详细安全规则见：

```
SECURITY.md
```
