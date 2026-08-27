# Azure Production Terraform IaC

> 仓库名 `k3s-gitops` 为历史命名。当前仓库的唯一主线是：**使用 Terraform 管理 Azure 生产基础设施**。

## 仓库边界

本仓库负责：

- Azure 网络：VNet、Subnet、NSG、NAT Gateway、Private DNS、Private Endpoint
- Azure 计算与容器基础设施：AKS、Node Pool、Workload Identity
- 数据与平台服务：PostgreSQL、Redis、ACR、Key Vault
- 流量入口基础设施：Load Balancer、Application Gateway / WAF
- 可观测性与治理：Log Analytics、Diagnostic Settings、Azure Policy、Defender
- Terraform State、Plan、Apply、Drift Detection、Policy Gate、OIDC 身份认证
- AKS / ACR 等基础设施级发布后验证

本仓库**不负责**：

- 业务应用源码
- `enterprise-cmdb` 的 Helm Chart
- 业务 Kubernetes Deployment / Service / Ingress
- 应用镜像构建与镜像 Tag 策略
- 应用级 HTTPS / Ingress 验证

应用交付内容应放在对应应用仓库中，而不是和 Azure IaC 混在一起。

详细边界见：`docs/repository-boundaries.md`。

## 标准目录

```text
k3s-gitops/
├── .github/
│   ├── CODEOWNERS
│   ├── dependabot.yml
│   └── workflows/               # Terraform / Azure 基础设施 CI/CD
├── docs/                        # IaC 规范、治理、验收和运维文档
├── infrastructure/
│   └── terraform/
│       ├── environments/
│       │   └── production/      # 唯一生产 Root Module
│       └── modules/             # 可复用 Azure Terraform Modules
├── .gitignore
├── README.md
└── SECURITY.md
```

禁止重新在根目录新增：

```text
helm/
kubernetes/
application/
services/
```

这些内容属于应用交付域，不属于基础设施 IaC 域。

## Terraform 入口

生产 Root Module：

```bash
cd infrastructure/terraform/environments/production
```

公共 Module：

```text
infrastructure/terraform/modules/
```

不要在仓库根目录执行 Terraform，也不要创建第二套 Terraform Root。

## 生产变更流程

```text
Terraform Change
      |
      v
Pull Request
      |
      +--> fmt / validate
      +--> security / policy checks
      +--> review
      |
      v
Production Plan
      |
      v
Approval
      |
      v
OIDC Authentication
      |
      v
Terraform Apply
      |
      v
Azure / AKS Infrastructure Verification
      |
      v
Drift Detection
```

原则：

- Git 是基础设施变更审计入口
- Terraform State 是资源生命周期事实依据
- Production Apply 使用 GitHub Actions + Azure OIDC
- 禁止长期 Azure Secret / Access Key 作为常规认证方式
- 核心资源的 destroy / replace 必须被 Gate 阻断或人工复核
- Apply 后必须做基础设施状态验证

## 已管理的主要能力

### Kubernetes / Compute

- Azure Kubernetes Service (AKS)
- Azure CNI
- 多 Node Pool / Availability Zone
- OIDC Issuer
- Workload Identity

### Network

- Virtual Network / Subnet
- Network Security Group
- NAT Gateway
- Load Balancer
- Application Gateway / WAF
- Private Endpoint
- Private DNS

### Data / Platform

- PostgreSQL Flexible Server
- Azure Cache for Redis
- Azure Container Registry
- Azure Key Vault

### Observability / Governance

- Log Analytics
- Diagnostic Settings
- Azure Monitor
- Azure Policy
- Defender for Cloud

## 已有 Azure 资源接管

已有资源不得直接重新创建，应通过 Terraform Import 接管：

```text
Azure Existing Resource
        |
        v
Terraform Configuration
        |
        v
terraform import
        |
        v
terraform plan
        |
        v
No destructive change
```

第一次接管的目标是：

```text
No changes
```

如果出现 `destroy`、`replace` 或意外 `create`，禁止直接 Apply。

## State 与生产保护

生产 State 必须使用远端 Backend，并具备版本和恢复能力。

核心资源应根据风险配置：

```hcl
lifecycle {
  prevent_destroy = true
}
```

重点保护：AKS、数据库、Key Vault、核心网络、Redis 等生产资源。

## 文档入口

IaC 治理、OIDC、资源命名、Import、Drift Detection、生产验收等文档统一放在：

```text
docs/
```

安全要求见：`SECURITY.md`。

## Repository Rule

新增文件前先判断：

```text
这是 Azure 基础设施生命周期的一部分吗？
  |
  +-- 是 --> 本仓库
  |
  +-- 否 --> 对应应用 / 平台交付仓库
```

目标是让本仓库始终保持：**Terraform-first、Infrastructure-only、Production-governed**。
