# Repository + State + Identity Model V1

## 1. 生产目标 Repo 模型

```text
azure-platform-iac/
├── bootstrap/
├── management-groups/
├── policy/
├── connectivity/
├── identity/
├── management/
├── acr/
├── aks/
└── modules/

azure-workload-iac/
├── workloads/
│   ├── payment/
│   │   ├── dev/
│   │   ├── test/
│   │   └── prod/
│   └── ...
└── modules/

cicd-templates/
├── github-actions/
├── azure-devops/
├── terraform/
├── security/
└── deploy/

build-images/
├── go/
├── python/
├── java/
├── cpp/
└── infra-toolbox/

gitops-environments/
├── clusters/
│   ├── dev/
│   ├── test/
│   └── prod/
└── applications/

app-*/
├── source
├── tests
├── Dockerfile
└── minimal CI adapter
```

当前 `k3s-gitops` 仓库承担实验集成角色，但后续会按上述责任拆分，不把所有企业资产永久堆在一个 Repo 中。

---

## 2. Repo 与 Owner

| Repository | Owner | 主要变更 | 生产权限 |
|---|---|---|---|
| azure-platform-iac | Platform/SRE | Azure 平台 | Protected Apply |
| azure-workload-iac | Workload + Platform Guardrail | 应用 Azure 资源 | Scoped Apply |
| cicd-templates | DevOps/Platform | Pipeline 标准 | 无直接业务数据权限 |
| build-images | DevOps/Platform | Build Runtime | ACR build image push |
| gitops-environments | Platform + Workload | K8s desired state | Flux reconciliation |
| app-* | Application Team | 应用源码 | Build/publish artifact |

---

## 3. Branch 模型

优先 Trunk-based：

```text
main
│
├── feature/*
├── fix/*
└── short-lived branches
```

不使用长期：

```text
dev branch
test branch
prod branch
```

作为环境真相来源。

环境差异放在：

- Terraform environment configuration
- GitOps environment directory
- Azure DevOps Environment
- Environment-specific identity / state

而不是靠长期 Git 分支漂移。

---

## 4. Terraform Root Module 模型

Module 与 Environment Stack 分离：

```text
modules/
├── aks/
├── acr/
├── network/
├── identity/
└── workload-base/

stacks/
├── platform/
│   ├── connectivity/
│   ├── identity/
│   └── aks/
│
└── workloads/
    ├── dev/payment/
    ├── test/payment/
    └── prod/payment/
```

原则：

- Module 定义可复用能力。
- Stack/Root Module 定义一个真实 State 边界。
- Environment 配置不复制整份 Module 源码。

---

## 5. Terraform State 模型

Backend 使用 Azure Storage + Entra ID/RBAC。

示例：

```text
Storage Account: sttfstateplatformxxxx
Container: tfstate

Keys:
platform/governance.tfstate
platform/connectivity.tfstate
platform/identity.tfstate
platform/aks.tfstate
workload/dev/payment.tfstate
workload/test/payment.tfstate
workload/prod/payment.tfstate
```

生产建议平台 State 与 Workload State 进一步使用不同 Storage Account / Subscription scope，取决于组织规模和隔离要求。

State 禁止：

- commit to Git
- email/share manually
- developer local machine as source of truth
- shared storage key embedded in pipeline variables

---

## 6. State 权限

```text
plan-dev
└── read state

apply-dev
└── read/write state

plan-prod
└── read prod state

apply-prod
└── read/write prod state
```

不同 Environment Identity 不访问其他 Environment State。

平台 Stack Identity 和 Workload Stack Identity 也分开。

---

## 7. Azure Identity Naming

建议统一命名：

```text
uami-tf-platform-plan
uami-tf-platform-apply

uami-tf-payment-dev-plan
uami-tf-payment-dev-apply
uami-tf-payment-test-plan
uami-tf-payment-test-apply
uami-tf-payment-prod-plan
uami-tf-payment-prod-apply

uami-ci-app-build
uami-cd-gitops-bootstrap
```

GitHub / Azure DevOps 通过 Federated Credential 使用这些 UAMI，而不是创建长期 Secret。

---

## 8. RBAC Scope 原则

从最小 Scope 开始：

```text
Resource
  > Resource Group
    > Subscription
      > Management Group
```

只有确有必要才向上扩大 Scope。

示例：

```text
uami-tf-payment-dev-apply
    Contributor
    scope = rg-payment-dev
```

而不是：

```text
Contributor
scope = entire tenant/subscription
```

平台自动化可能需要更高 Scope，但必须独立身份、独立 Pipeline、独立审批。

---

## 9. Service Connection 模型

Azure DevOps：

```text
sc-tf-dev-plan
sc-tf-dev-apply
sc-tf-test-plan
sc-tf-test-apply
sc-tf-prod-plan
sc-tf-prod-apply
```

每个 Service Connection：

- Workload Identity Federation
- 明确允许的 Pipeline
- Environment-appropriate RBAC
- PROD 增加 Branch Control / Required Template / Approval / Lock

禁止选择“Grant access permission to all pipelines”作为生产默认值。

---

## 10. GitHub Environment 模型

GitHub Actions 如用于 Application CI：

```text
build
publish
```

如暂时承担 DEV 部署：

```text
dev
```

PROD 最终不依赖 GitHub CI 身份直接持有 cluster-admin。

GitHub Environment OIDC subject 与 Azure Federated Credential 对齐。

---

## 11. GitOps Repo 模型

```text
gitops-environments/
├── clusters/
│   ├── dev/
│   │   ├── infrastructure/
│   │   └── apps/
│   ├── test/
│   └── prod/
│
└── apps/
    ├── payment/
    │   ├── base/
    │   └── overlays/
    └── ...
```

CI 构建完成后不直接重新 Build，而是更新 GitOps 中的 image digest：

```text
image:
  repository: <acr>/payment
  digest: sha256:...
```

Flux 负责 reconcile。

---

## 12. Artifact 模型

应用版本必须关联：

```text
Git Commit SHA
Build Run ID
Image Digest
SBOM
Signature/Attestation
Deployment Revision
```

可以从 Production Deployment 反查：

```text
Production Pod
 -> Image Digest
 -> Build
 -> Commit
 -> PR
```

也可以从 CVE 反查：

```text
Dependency/CVE
 -> SBOM
 -> affected images
 -> deployed environments
```

---

## 13. 变更链路

### Platform IaC

```text
feature branch
 -> PR
 -> plan
 -> platform review
 -> merge main
 -> protected apply
 -> verify
```

### Workload IaC

```text
feature branch
 -> PR
 -> workload plan
 -> review
 -> dev apply
 -> test promotion
 -> prod protected apply
```

### Application

```text
PR
 -> CI
 -> merge
 -> build immutable artifact
 -> publish ACR
 -> update dev GitOps
 -> verify
 -> promote same digest to test/prod
```

---

## 14. Drift Management

生产必须建立两类 Drift 检测：

### Terraform Drift

定期执行只读 Plan：

```text
terraform plan -detailed-exitcode
```

发现 Portal/CLI 手工改动。

### Kubernetes Drift

Flux reconciliation 负责将 Runtime 恢复到 Git desired state。

禁止把“手工改完能跑”当作最终状态。

---

## 15. V1 当前落地映射

当前：

```text
k3s-gitops
├── enterprise-cicd/
│   ├── architecture/      <- 本阶段重点
│   ├── terraform/
│   ├── azure-pipelines/
│   ├── helm/
│   └── examples/
└── .github/workflows/
```

下一步不是马上扩资源，而是先根据本模型重构现有 Terraform/Pipeline：

1. 把 Bootstrap 与长期 IaC 分开。
2. 定义 dev/test/prod logical stacks。
3. 定义 Plan/Apply identity contract。
4. 定义 Terraform backend key 规则。
5. 定义 Azure DevOps protected environment 模型。
6. 再开始四语言 Build Platform。
