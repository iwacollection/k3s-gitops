# Enterprise Control Boundaries V1

## 1. 为什么先定义边界

企业级 IaC + CI/CD 最大风险不是 YAML 写错，而是“谁都能做任何事”。

本文件把平台权限拆成明确边界，避免：

- Application Pipeline 拥有 Subscription Contributor。
- DEV 身份可以操作 PROD。
- Terraform Plan 和 Apply 共用高权限身份。
- CI 可以任意 `kubectl` 进入生产集群。
- Pipeline YAML 作者能删除审批后直接发布。
- 手工 Portal 修改长期偏离 IaC。

---

## 2. Team Ownership

| Domain | Primary Owner | Workload Team Access |
|---|---|---|
| Management Groups | Platform Team | No direct write |
| Azure Policy | Platform/Security | No direct write |
| Shared Network | Platform/Network | Request/consume |
| Shared ACR | Platform Team | scoped push/pull |
| AKS Platform | Platform/SRE | namespace/workload scope |
| Workload Azure Resources | Workload Team | scoped IaC write |
| Application Source | Workload Team | full through Git governance |
| Pipeline Templates | Platform/DevOps | consume/PR changes |
| GitOps Environments | Platform + Workload | environment-specific PR |
| Production Approval | Designated approvers | explicit approval |

---

## 3. Subscription Boundary

### Target Production

```text
Tenant
│
├── Platform subscriptions
│   ├── Identity
│   ├── Connectivity
│   └── Management
│
└── Application landing zones
    ├── app-dev
    ├── app-test
    └── app-prod
```

### Current Lab

```text
one subscription
│
├── logical platform boundary
├── logical dev boundary
├── logical test boundary
└── logical prod boundary
```

即使只有一个 Subscription，RBAC Scope 仍优先下沉到 Resource Group / Resource，而不是把所有 Identity 绑到 Subscription Contributor。

---

## 4. Repository Boundary

目标拆分：

```text
azure-platform-iac
azure-workload-iac
cicd-templates
build-images
gitops-environments
application-* repositories
```

规则：

- 平台级 Terraform 不进入业务 Repo。
- 应用 Repo 不拥有修改生产平台 Terraform 的默认权限。
- Pipeline Template 独立版本化。
- GitOps Repo 是 Kubernetes Desired State，而不是源代码构建 Repo。

---

## 5. State Boundary

Terraform State 按 blast radius 拆分。

推荐：

```text
tfstate
│
├── platform
│   ├── governance
│   ├── connectivity
│   ├── identity
│   └── aks
│
├── dev
│   └── workload-<name>
│
├── test
│   └── workload-<name>
│
└── prod
    └── workload-<name>
```

不推荐：

```text
one terraform.tfstate
└── entire Azure estate
```

State 拆分原则：

1. 生命周期不同就倾向拆。
2. Owner 不同就拆。
3. 权限边界不同就拆。
4. 高风险共享基础设施与应用资源拆。
5. 不为“目录好看”过度拆分。

---

## 6. Identity Boundary

### IaC

```text
plan-dev     -> read Azure + read state
apply-dev    -> write dev + write state

plan-test    -> read test
apply-test   -> write test

plan-prod    -> read prod
apply-prod   -> narrowly scoped prod write
```

### Application CI

```text
ci-build
├── read source
├── read dependency proxy
└── push artifact to ACR
```

它不需要生产 Azure Contributor。

### GitOps CD

Flux 使用 AKS 内部身份/扩展访问 GitOps Repository 和 ACR Pull；生产应用发布不依赖 CI 持有 cluster-admin。

---

## 7. Environment Boundary

```text
DEV
- 自动化程度最高
- Merge 后可自动 deploy
- 快速反馈

TEST
- 同一 artifact promotion
- integration/e2e gates
- 可有自动/人工混合 gate

PROD
- same immutable artifact
- protected environment
- branch control
- approval/check
- exclusive lock where mutable infrastructure is changed
- post-deploy verification
```

环境晋级改变的是部署声明，不重新 Build Artifact。

---

## 8. Pipeline Boundary

### Application CI 允许

- Build
- Test
- Scan
- Package
- Push ACR
- Generate SBOM
- Sign

### Application CI 默认不允许

- Subscription-wide Contributor
- Terraform platform apply
- PROD cluster-admin
- 修改 Azure Policy
- 修改共享网络

### IaC Pipeline 允许

仅使用对应环境和 stack 的身份执行 Terraform。

### GitOps Controller 允许

仅对其管理范围执行 Kubernetes reconciliation。

---

## 9. Approval Boundary

Production 控制不能只存在于 YAML。

需要外置到受保护 Resource：

```text
Azure DevOps Environment / Service Connection
│
├── Branch Control
├── Required Template
├── Approval
└── Exclusive Lock
```

原因：Pipeline YAML 作者不应该拥有删除生产 Guardrail 的能力。

---

## 10. Human Access Boundary

日常原则：

```text
Human -> Git PR -> Pipeline -> Azure
```

而不是：

```text
Human -> Portal/CLI -> PROD resource mutation
```

Portal/CLI 在生产主要用于：

- read-only inspection
- incident investigation
- approved break-glass

Break-glass 后必须补回 IaC/GitOps，消除 drift。

---

## 11. Separation of Duties

高成熟度目标：

```text
Code Author != Production Approver
Pipeline Author != Service Connection Owner
Workload Developer != Platform Policy Admin
Terraform Plan Identity != Apply Identity
Application CI Identity != Production IaC Identity
```

实验环境可由一个人扮演多个角色，但代码与权限模型仍保持逻辑分离。
