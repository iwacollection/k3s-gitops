# Azure Enterprise IaC + CI/CD Control Plane V1

## 1. 目标

本架构的目标不是搭建一条可以执行 `terraform apply` 或 `helm upgrade` 的流水线，而是定义 Azure 企业环境中 IaC、CI、CD、身份、审批、制品和环境之间的管理边界。

核心目标：

- Azure 基础设施只能通过受治理的 IaC 变更。
- 应用构建和基础设施变更解耦。
- DEV / TEST / PROD 具有独立身份和授权边界。
- Pipeline YAML 不能成为生产权限的唯一控制点。
- 构建一次，使用同一个 Artifact/Image Digest 在环境间晋级。
- Kubernetes 期望状态由 GitOps 管理，而不是允许 CI 任意执行生产 `kubectl`。
- 所有长期云凭据逐步淘汰，统一使用 OIDC / Workload Identity Federation。
- Terraform State 是受保护的平台数据，不进入 Git。
- 平台团队设置 Guardrails，业务团队在 Guardrails 内自治。

---

## 2. Azure 企业目标拓扑

```text
Microsoft Entra Tenant
│
└── Management Group Hierarchy
    │
    ├── Platform
    │   ├── Identity Subscription
    │   ├── Connectivity Subscription
    │   └── Management Subscription
    │
    └── Landing Zones
        │
        ├── Workload DEV Subscription
        ├── Workload TEST Subscription
        └── Workload PROD Subscription
```

当前实验环境只有一个 Azure Subscription，因此 V1 实验映射为：

```text
Azure subscription 1
│
├── rg-platform-cicd
├── rg-workload-dev
├── rg-workload-test        # 后续模拟
└── rg-workload-prod        # 后续模拟，不默认创建
```

重要原则：

> 实验环境可以缩减物理边界，但不能缩减代码里的逻辑边界。

因此 Terraform、Identity、State 和 Pipeline 从第一天就按照 DEV / TEST / PROD 可独立拆分设计。

---

## 3. 五个管理面

```text
                    Enterprise Delivery Platform
                               │
        ┌──────────────────────┼───────────────────────┐
        │                      │                       │
   Azure Control Plane     IaC Control Plane      Delivery Control Plane
        │                      │                       │
      ARM/RBAC              Terraform             Azure DevOps/GitHub
      Policy                State/Modules          Pipeline Templates
        │                      │                       │
        └──────────────┬───────┴──────────────┬────────┘
                       │                      │
                 Artifact Plane          Runtime Plane
                       │                      │
                   ACR/Packages              AKS
                       │                    Flux/Helm
                       └──────────────────────┘
```

### 3.1 Azure Control Plane

负责：

- Management Group
- Subscription
- Azure Policy
- RBAC
- Managed Identity
- Network Guardrails
- Resource Locks（必要时）

它定义“什么允许发生”。

### 3.2 IaC Control Plane

负责：

- Terraform Modules
- Root Modules / Stacks
- Remote State
- Plan / Apply 身份分离
- Drift Detection
- IaC Policy Check

它定义“Azure 资源应该长什么样”。

### 3.3 Delivery Control Plane

负责：

- GitHub Actions
- Azure DevOps Pipelines
- Required Templates
- Branch Policies
- Environment Approvals / Checks
- Agent / Runner 治理

它定义“变更如何进入 Azure”。

### 3.4 Artifact Plane

负责：

- ACR OCI Images
- Maven / PyPI / Go / C++ packages
- SBOM
- Signatures / Attestations
- Artifact retention

它定义“什么产物允许被发布”。

### 3.5 Runtime Plane

负责：

- AKS
- Kubernetes Namespaces
- Helm releases
- Flux GitOps
- Runtime Policy
- Workload Identity

它定义“应用如何运行”。

---

## 4. IaC 分层

IaC 不使用一个仓库同时管理所有 Azure 资源。

```text
IaC
│
├── Platform IaC
│   ├── Management Groups
│   ├── Policies
│   ├── Shared Network
│   ├── Shared Identity
│   ├── Shared Monitoring
│   ├── Shared ACR
│   └── AKS Platform
│
└── Workload IaC
    ├── Database
    ├── Cache
    ├── Storage
    ├── Service Bus
    ├── Workload Identity
    └── Application-specific Azure resources
```

### Platform IaC Owner

默认：Platform / SRE / Cloud Team。

业务开发不能通过自己的 Application Pipeline 修改 Management Group、Azure Policy、共享网络或生产 AKS 平台。

### Workload IaC Owner

默认：Workload Team，在平台 Guardrail 下自治。

可以管理自己的应用资源，但不能突破上层 Azure Policy / RBAC 边界。

---

## 5. 三条独立 Pipeline

### 5.1 Application CI

```text
Source
  │
  ├── Compile
  ├── Unit Test
  ├── Lint
  ├── SAST / SCA
  ├── Package
  ├── Container Build
  ├── SBOM
  ├── Sign
  └── Push ACR
```

CI 的输出必须是不可变 Artifact：

```text
app@sha256:<digest>
```

不允许 PROD 再次 Build。

### 5.2 Infrastructure Delivery

```text
Terraform PR
   │
   ├── fmt
   ├── validate
   ├── lint
   ├── policy/security
   └── terraform plan
        │
        v
      Review
        │
       Merge
        │
        v
Environment Apply Pipeline
   │
   ├── protected identity
   ├── approval/check
   ├── exclusive lock
   ├── terraform apply
   └── verification
```

### 5.3 Kubernetes CD / GitOps

目标生产模型：

```text
Application CI
    │
    v
ACR Image Digest
    │
    v
GitOps Environment Repository
    │
    v
Flux
    │
    v
AKS
```

生产环境中 CI 不应该默认持有任意 `kubectl` 管理权限。

---

## 6. DEV / TEST / PROD 身份模型

每个环境独立身份，不创建跨环境万能身份。

```text
DEV
├── tf-plan-dev
├── tf-apply-dev
└── app-deploy-dev

TEST
├── tf-plan-test
├── tf-apply-test
└── app-deploy-test

PROD
├── tf-plan-prod
├── tf-apply-prod
└── app-deploy-prod
```

Terraform Plan 与 Apply 权限不同：

```text
Plan Identity
  -> Reader + State Read

Apply Identity
  -> Required Resource Write Roles + State Write
```

禁止：

```text
one-service-principal -> Contributor on entire subscription -> DEV/TEST/PROD
```

认证统一目标：

```text
GitHub / Azure DevOps
       │
       | OIDC / WIF
       v
Microsoft Entra ID
       │
       v
Short-lived Azure token
```

不保存长期 Client Secret。

---

## 7. 生产审批不能只写在 YAML

Pipeline YAML 属于可变代码，因此生产控制必须放到 Pipeline 作者无法随意绕过的位置。

Azure DevOps 推荐使用：

- Environment approvals/checks
- Service Connection permissions
- Branch Control
- Required Template
- Exclusive Lock
- Azure Monitor checks（成熟阶段）

生产概念模型：

```text
prod-apply Service Connection
│
├── Only approved pipelines
├── Required Template
├── Branch Control: main/release only
├── Manual Approval
└── Exclusive Lock
```

即使开发者删除 YAML 中的“approval stage”，仍然无法直接使用生产 Service Connection。

---

## 8. Artifact Promotion

严格执行：

```text
Build Once -> Promote Many
```

例：

```text
Commit abc123
   │
   v
Image Digest sha256:999...
   │
   ├── DEV
   │
   ├── TEST
   │
   └── PROD
```

DEV、TEST、PROD 使用同一 digest。

禁止：

```text
DEV build -> image A
TEST build -> image B
PROD build -> image C
```

---

## 9. GitHub Actions 与 Azure DevOps 的角色

V1 推荐角色分工：

```text
GitHub Actions
└── Application CI
    ├── Build
    ├── Test
    ├── Security
    └── Publish Artifact

Azure DevOps
└── Enterprise Governance / IaC Delivery
    ├── Terraform Plan/Apply
    ├── Environment Protection
    ├── Required Templates
    ├── Approval/Checks
    └── Exclusive Lock

Flux
└── AKS Application CD
```

两套 Pipeline 系统可以共存，但不能同时成为 PROD 的无约束部署控制面。

---

## 10. 当前实验环境映射

已有资源：

```text
Azure Subscription
└── group-test
    └── k8s-test-cicd (AKS Automatic)
```

V1 不再创建第二套 AKS。

后续实验资源：

```text
rg-platform-cicd
├── ACR Standard
├── Terraform State Storage
├── Managed Identities
└── CI/CD platform supporting resources

existing group-test
└── k8s-test-cicd
    └── dev namespace / GitOps target
```

PROD 只模拟管理逻辑，不默认创建生产云资源。

---

## 11. 变更原则

### Azure Platform Change

必须：

```text
PR -> Plan -> Review -> Merge -> Protected Apply -> Verify
```

### Application Change

必须：

```text
PR -> CI -> Build Immutable Artifact -> Deploy DEV -> Promote -> PROD
```

### Emergency / Break Glass

允许极少数 Break Glass 身份，但：

- 不用于日常操作。
- 使用必须审计。
- 使用后必须将实际状态重新同步到 IaC/GitOps。
- 不允许长期形成 Portal Drift。

---

## 12. V1 实施顺序

```text
Phase 1  Control Boundaries
Phase 2  Repository + State Model
Phase 3  Identity + RBAC Model
Phase 4  Terraform Module Model
Phase 5  Azure DevOps IaC Governance
Phase 6  GitHub Application CI
Phase 7  Build Images: Go/Python/Java/C++
Phase 8  Artifact + ACR Governance
Phase 9  Flux GitOps
Phase 10 DEV -> TEST -> PROD Promotion
Phase 11 Security / SBOM / Signing
Phase 12 Runner / Agent Platform
Phase 13 Drift / Failure / Rollback / DR
```

在 Phase 1-3 未稳定之前，不扩大 Azure 资源创建范围。
