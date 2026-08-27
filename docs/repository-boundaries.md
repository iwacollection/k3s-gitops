# Repository Boundaries

## 1. 目的

本文件定义 `k3s-gitops` 的仓库职责，避免 Terraform IaC、Kubernetes 应用清单、Helm Chart 和业务发布流程继续混在同一个仓库中。

## 2. 当前定位

虽然仓库名保留了历史上的 `k3s-gitops`，但当前实际定位是：

> Azure Production Infrastructure as Code Repository

基础设施的唯一主实现方式是 Terraform。

## 3. 可以进入本仓库的内容

### Terraform

- `infrastructure/terraform/environments/production`
- `infrastructure/terraform/modules/*`
- Backend / State 管理
- Import / Drift Detection
- Terraform Policy / Security Gate

### Azure 基础设施

- Resource Group
- VNet / Subnet / NSG
- NAT Gateway / Load Balancer
- Application Gateway / WAF
- AKS / Node Pool
- ACR
- Key Vault
- PostgreSQL / Redis
- Private Endpoint / Private DNS
- Log Analytics / Diagnostic Settings
- Azure Policy / Defender
- Managed Identity / Workload Identity / RBAC

### 基础设施级验证

允许：

- AKS 是否存在、Node 是否 Ready
- AKS kubelet identity 是否具备 ACR `AcrPull`
- Azure 资源是否创建成功
- Terraform Apply 后是否产生 Drift
- Private Endpoint / DNS / RBAC 是否正确

## 4. 不应进入本仓库的内容

### 应用源码

例如：

```text
services/
apps/
src/
enterprise-cmdb application code
```

### 应用 Helm Chart

例如历史内容：

```text
helm/enterprise-cmdb/
```

这些应放入 `enterprise-cmdb` 自己的应用仓库或独立 GitOps/Application Delivery 仓库。

### 业务 Kubernetes Manifest

例如：

```text
kubernetes/enterprise-cmdb/
Deployment
Service
Ingress
ConfigMap
Application Secret template
```

基础设施仓库不应该决定某个业务应用如何发布。

### 应用发布 Workflow

例如：

- Container image mutable-tag check
- enterprise-cmdb ingress verification
- Application image build / push
- Helm deploy / rollback

这些 Workflow 应跟随应用代码和应用发布生命周期。

## 5. AGIC / Ingress Controller 如何处理

AGIC、Ingress Controller、Application Gateway 相关内容需要区分两个层次：

```text
Azure Infrastructure
├── Application Gateway
├── WAF
├── Managed Identity
├── AKS integration
└── RBAC
        -> Terraform IaC 仓库

Kubernetes Application Delivery
├── 某个业务 Ingress
├── 某个业务 Service
├── 某个业务 TLS 配置
└── 某个业务 Helm values
        -> 应用 / GitOps 仓库
```

因此不要因为业务使用 AKS，就把所有 Kubernetes YAML 都放进 IaC 仓库。

## 6. Workflow 边界

推荐保留的 Workflow 类型：

```text
Terraform PR Validation
Terraform Plan
Terraform Policy / Security Gate
Terraform Production Approval
Terraform Apply
Terraform Drift Detection
Terraform Post Apply Verification
Azure / AKS Infrastructure Verification
```

不建议保留：

```text
Application Image Policy
Application Helm Deployment
Application Kubernetes Deployment
Application-specific Ingress Verification
```

## 7. 目录治理规则

以后新增目录时，先做一次判断：

```text
Does this file manage Azure infrastructure lifecycle?
│
├── Yes
│   └── infrastructure/terraform or IaC workflow/docs
│
└── No
    └── move to application/platform-delivery repository
```

仓库根目录应该长期保持很少的一级目录。

## 8. 本次清理原则

本次整理只改变仓库职责边界，不改 Terraform Resource/Module 逻辑：

- 保留 `infrastructure/terraform/**`
- 保留 IaC / Azure 基础设施 Workflow
- 移除历史应用 Helm/Kubernetes 内容
- 移除与这些应用文件绑定的 Workflow
- 通过 README 明确禁止再次混入

历史内容仍可通过 Git 历史恢复，因此清理不会造成不可追溯的数据丢失。
