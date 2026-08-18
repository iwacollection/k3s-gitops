# Azure Enterprise IaC + CI/CD Platform

> Microsoft Azure 企业级 IaC（Infrastructure as Code，基础设施即代码）与 CI/CD（持续集成/持续交付）管理平台。
>
> 核心原则：**Platform owns implementation; developers submit intent.**
> 平台团队维护 Terraform、Pipeline、Build Image、Policy 和发布策略；研发团队主要提交“我需要什么”的声明，而不是自己重新实现平台能力。

## 1. 平台目标

本目录不是一个单项目的流水线示例，而是一套可持续扩展的 Azure Platform Engineering（平台工程）控制面。

平台统一解决：

- Azure 基础设施如何申请、审核、创建、变更和回收
- Terraform Module、Root Stack、Remote State、Identity 和 RBAC 如何治理
- Go / Python / Java / C++ 如何使用统一、版本化的编译环境
- 内网依赖代理、缓存隔离、构建可重复性如何保证
- 制品如何扫描、生成 SBOM、签名并形成 Provenance（构建来源证明）
- DEV -> TEST -> PROD 如何使用同一个 Artifact Digest 晋级
- AKS 如何通过 Flux GitOps Pull 模式部署，而不是让 CI 持有生产集群管理员权限
- Azure DevOps 与 GitHub Actions 如何分工而不形成双写控制面
- 审批、锁、回滚、验证、审计和可观测性如何形成完整闭环

## 2. 当前实验环境与生产目标

### 当前 Lab

- Azure Subscription：单 Subscription 实验环境
- AKS：`k8s-test-cicd`
- Resource Group：`group-test`
- AKS 模式：AKS Automatic / Standard
- GitHub Repository：`iwacollection/k3s-gitops`
- 当前控制面 PR：保持 Draft，先完成框架和自动验证，再显式开启真实 Azure Apply / Flux Bootstrap

### 生产目标

生产环境不把一个 Subscription / 一个 Identity / 一个 State 用到底，而是按照 Azure Landing Zone 思路拆分管理边界：

```text
Microsoft Entra Tenant
|
+-- Platform Landing Zone
|   +-- Identity
|   +-- Connectivity
|   +-- Management / Observability
|   +-- Shared CI/CD Services
|
+-- Application Landing Zones
    +-- DEV Subscription
    +-- TEST Subscription
    +-- PROD Subscription
```

当前 Lab 用 Resource Group 模拟环境边界，但 Terraform、State、Identity、Pipeline Contract 从第一天就按未来多 Subscription 设计。

## 3. 总体架构

```text
                           Developer
                               |
             +-----------------+------------------+
             |                 |                  |
         IaC Request       Application Code    Release Request
             |                 |                  |
             v                 v                  v
       IaC Service        CI Build Service    Release Service
          Catalog            Catalog             Catalog
             |                 |                  |
             v                 v                  v
      Schema / Policy     Standard Profile    Promotion Policy
             |                 |                  |
             v                 v                  v
      Terraform Plan       Build / Test      Protected GitOps PR
             |                 |                  |
          Review            Security               v
             |                 |              Git Desired State
             v                 v                  |
     Protected Apply          ACR                 v
             |                 |                Flux
             v                 |                  |
            Azure             +---- Digest ------> AKS
```

## 4. 三个 Service Catalog

### 4.1 IaC Service Catalog

**IaC Service Catalog（基础设施服务目录）**：平台把 Azure 资源做成标准产品。

研发默认不直接写 Terraform `.tf`。正常流程只提交：

```text
enterprise-cicd/iac-requests/<environment>/<request>.json
```

每个标准资源模板由平台维护：

```text
iac-catalog/services/<service>/<version>/
├── catalog.json
├── request.schema.json
├── defaults.json
├── policy.json
├── request.example.json
└── README.md
```

职责：

- `request.schema.json`：研发允许填写哪些字段
- `defaults.json`：平台注入安全默认值
- `policy.json`：环境、SKU、网络、容量等限制
- `catalog.json`：映射到哪个 Terraform Module / Root Stack
- Terraform Module：真正实现 Azure Resource

标准链路：

```text
Developer Request
    -> Schema Validate
    -> Policy Validate
    -> Render controlled tfvars
    -> Terraform Plan
    -> PR Review
    -> Merge
    -> Protected Apply
    -> Azure
    -> Verification
```

### 4.2 CI Build Service Catalog

**Build Profile（标准构建配置模板）**：研发选择标准构建套餐，不自己复制几十套 Pipeline。

当前 V1：

| Language | Build Profile | Platform Build Image |
|---|---|---|
| Java | `java/springboot-maven-v1` | `java21-maven:v1` |
| Python | `python/python-uv-v1` | `python-uv:v1` |
| Go | `go/go-service-v1` | `go-builder:v1` |
| C++ | `cpp/cmake-conan-v1` | `cpp-cmake-conan:v1` |

所有 Profile 使用统一生命周期：

```text
prepare -> verify -> package
```

研发通过 `application-definitions/` 声明应用、Owner、Build Profile、Artifact、Dockerfile 和默认 Release Profile。

平台负责：编译器/SDK 版本、Dependency Proxy、Cache、测试、安全扫描、SBOM、BuildKit Provenance、Cosign Signing 和 Artifact Digest。

### 4.3 Release / CD Service Catalog

CD 不重新 Build：**Build Once, Promote Same Digest**。

当前发布策略：

- `rolling/rolling-v1`
- `canary/canary-v1`
- `blue-green/blue-green-v1`

Release Request 只声明 Application、Artifact Repository、Artifact Digest、From/To Environment、Release Profile 和 Change Reason。

平台决定环境跳转、PROD 审批、Rollout Strategy、Verification 和 Rollback。

## 5. IaC 管理模型

### 5.1 Terraform Module 与 Root Stack

**Module（模块）**：可复用基础设施实现。**Root Stack（根资源栈）**：真正对应独立 State / 权限 / 生命周期的部署单元。

```text
terraform/
├── bootstrap/
├── state/
├── modules/
│   ├── resource-group/
│   ├── managed-identity/
│   ├── acr/
│   ├── network/
│   ├── aks/
│   └── workload-base/
└── stacks/
    ├── platform/
    │   ├── governance/
    │   ├── connectivity/
    │   ├── identity/
    │   ├── acr/
    │   └── aks/
    └── workloads/
        ├── dev/
        ├── test/
        └── prod/
```

### 5.2 Terraform State

State 不能进 Git，也不能所有资源共用一个巨大 State。

平台 Stack 示例：`platform/identity.tfstate`、`platform/connectivity.tfstate`、`platform/aks.tfstate`。

Catalog Request 使用更细粒度 State：

```text
catalog/dev/acr/payment-acr.tfstate
catalog/test/redis/payment-redis.tfstate
catalog/prod/database/order-db.tfstate
```

拆分依据：Owner、生命周期、权限边界和 Blast Radius（故障/变更影响范围）。

### 5.3 Plan / Apply 分权

```text
DEV   tf-plan-dev   / tf-apply-dev
TEST  tf-plan-test  / tf-apply-test
PROD  tf-plan-prod  / tf-apply-prod
```

禁止一个万能 Contributor Identity 管 DEV/TEST/PROD、长期 Client Secret、研发个人账号执行生产 Apply、PR Pipeline 直接 Apply。优先 OIDC / WIF（Workload Identity Federation，工作负载身份联合）。

## 6. CI 管理模型

```text
Checkout
 -> Resolve Application Definition
 -> Resolve Build Profile
 -> Dependency Proxy / Cache
 -> Source Security Scan
 -> Platform Build Image
 -> prepare / verify / package
 -> Build Container
 -> SBOM + Provenance
 -> Push ACR
 -> Container Scan
 -> Cosign Sign
 -> Resolve sha256 Digest
 -> Release Evidence
```

CI 明确禁止 `kubectl apply`、生产 `helm upgrade`、获取 PROD AKS Admin kubeconfig、`terraform apply` 和使用 `latest` 作为发布身份。

## 7. Dependency Proxy 与 Cache

- Dependency Proxy：共享只读依赖源，例如 Maven / PyPI / Go Proxy / Conan Remote。
- Job Workspace：每个 Job 独立，不能多个构建共享可写源码目录。
- Dependency Cache：Key 绑定 Lock File、Build Profile、Build Image Version、Architecture 等输入。

避免缓存污染、ABI 不一致、并发写损坏、不同编译器共用 C++ Cache、依赖版本漂移。

## 8. Artifact 与软件供应链安全

```text
Source Commit
 -> Build Profile
 -> Build Image Version
 -> Tests
 -> Security Evidence
 -> SBOM
 -> Provenance
 -> Signature
 -> ACR Digest
```

环境晋级使用 `acr.example/payment-api@sha256:...`，不依赖可变 `latest` Tag。

## 9. CD / GitOps 管理模型

### 9.1 Pull-based GitOps

目标模型：

```text
CI -> ACR -> Release Request -> Protected GitOps PR
                                |
                                v
                         Git Desired State
                                |
                                v
                         Flux in AKS
                                |
                                v
                           Reconcile
```

Flux 是 Pull-based GitOps Controller（拉取式 GitOps 控制器）：集群主动读取 Git Desired State，不要求普通 Build Runner 持有 AKS Admin 权限。

### 9.2 环境晋级

只允许 `build -> dev -> test -> prod`，同一个 Digest 从 DEV 一直晋级到 PROD，不允许默认 `build -> prod`。

### 9.3 Rollback

Rollback 使用 previously-approved digest（之前审核通过的制品摘要），不重新 Build。

## 10. GitHub Actions / Azure DevOps / Flux 分工

### GitHub Actions

Application CI：Build Profile、Test、Security Gate、Container Build、SBOM/Signing/Provenance、Push ACR、Release Evidence。

### Azure DevOps

IaC / Environment Governance：Terraform Request Plan/Apply、Service Connection、Protected Environment、Approval、Branch Control、Required Template、Exclusive Lock。

### Flux

Kubernetes 实际 CD：Pull Git Desired State、Reconcile AKS、Drift Correction、Kustomize/Helm Controller。

原则：同一职责只有一个最终写控制面，避免 GitHub Actions 与 Azure DevOps 同时直接修改 PROD AKS。

## 11. DEV / TEST / PROD 治理

```text
DEV
- 快速反馈
- Schema / Policy
- 自动验证

TEST
- 集成验证
- 安全门禁
- 与 PROD 尽量同构

PROD
- Protected Environment
- Required Reviewer
- Branch Control
- Required Template
- Exclusive Lock
- Same Digest Promotion
- Verification
- Rollback Evidence
```

## 12. 研发日常工作方式

### 12.1 申请 Azure 资源

提交 `iac-requests/dev/payment-redis.json`：

```text
PR -> Schema -> Policy -> Terraform Plan -> Review -> Merge -> Protected Apply
```

研发不需要手写 `azurerm_*`。

### 12.2 新应用接入 CI

提交 `application-definitions/payment-api.json` 并选择 `buildProfile`，统一 Reusable Workflow 执行 Build Platform。

### 12.3 发布应用

选择 CI 已生成的 Artifact Digest，提交 `release-requests/<app>-to-<env>.json`：

```text
Release Validate
 -> Promotion Policy
 -> GitOps PR
 -> Review / Approval
 -> Merge
 -> Flux Reconcile
 -> Verification
 -> Evidence
```

## 13. 平台团队工作方式

平台升级标准版本而不是要求每个项目自己升级：Build Image v1 -> v2、Terraform Template v1 -> v2、Release Profile v1 -> v2。升级必须经过 PR Review、Contract Validation、Golden Fixture 和迁移说明。

Catalog 不支持的新需求走：Developer Requirement -> Platform Review -> Module/Profile Enhancement -> New Version -> Golden Test -> Developer 选择新版本。

## 14. 自动化验证

当前/目标控制面持续执行：

- `Control Contract Validate`
- `Framework Structure Validate`
- `Terraform Framework Validate`
- `Platform Catalog Validate`
- `Build Platform Validate`
- `Build Profile Smoke`
- `GitOps Platform Validate`

Golden Fixture 会真实构建 Java / Python / Go / C++ 最小项目，防止平台 Profile 只“JSON 看起来正确”但真正编译失败。

## 15. 目录总览

```text
enterprise-cicd/
├── architecture/               # 总体架构设计
├── contracts/                  # Environment / State / Identity / Repo 契约
├── iac-catalog/                # 标准基础设施产品
├── iac-requests/               # 研发基础设施申请
├── terraform/                  # Module / Root Stack / State Renderer
├── azure-devops/               # IaC / Environment Governance
├── github-actions/             # Reusable CI / Promotion Workflow
├── ci-catalog/                 # Java/Python/Go/C++ Build Profile
├── application-definitions/    # 应用声明
├── ci-scripts/                 # 平台构建辅助逻辑
├── build-images/               # 版本化构建镜像
├── dependency-proxy/           # Maven/PyPI/Go/Conan 代理策略
├── artifacts/                  # ACR / Package / Promotion 契约
├── release-catalog/            # Rolling/Canary/Blue-Green
├── release-requests/           # 发布/晋级申请
├── promotion/                  # 晋级/验证/回滚策略
├── gitops/                     # Flux Desired State
├── security/                   # Policy/Scan/SBOM/Signing/RBAC
├── observability/              # Pipeline/Deployment/Platform Metrics
├── testing/                    # Contract/Integration/E2E/Golden Fixture
├── operations/runbooks/        # 故障处理与恢复手册
└── docs/                       # ADR/Standard/Onboarding
```

## 16. 安全硬规则

1. 禁止生产长期 Client Secret；优先 OIDC/WIF。
2. CI Identity 不拥有 PROD AKS Admin 权限。
3. Terraform Plan 与 Apply Identity 分离。
4. PROD Approval / Lock 不能只依赖业务 YAML 自己声明。
5. Artifact 必须使用不可变 Digest 晋级。
6. PROD 不重新 Build。
7. Terraform State 禁止提交 Git。
8. Catalog 外能力必须走平台例外/模板升级流程。
9. Build Workspace 不共享可写目录。
10. Release Rollback 使用已批准旧 Digest，不重新构建。

## 17. 当前实施状态

```text
Control Plane Architecture        DONE
Repo / State / Identity Contract  DONE
Terraform Module Framework        IN PROGRESS
IaC Service Catalog V1            IN PROGRESS (ACR first real product)
Build Platform V1                 DONE
Java/Python/Go/C++ Golden Smoke   DONE
Release Catalog V1                DONE
GitOps / Flux Execution           IN PROGRESS
Azure DevOps Protected Runtime    IN PROGRESS
Real Azure Apply                  NOT ENABLED BY DEFAULT
Real PROD Delivery                NOT ENABLED BY DEFAULT
```

## 18. 下一阶段

1. 完成 GitOps / Flux Execution Contract
2. Release Request 自动生成 Protected GitOps PR
3. DEV/TEST/PROD Overlay 与 Flux Kustomization
4. Deployment Verification / Rollback Evidence
5. Azure DevOps Request Plan/Apply Wrapper
6. 显式授权后发布 Platform Build Images 到 ACR
7. 用现有 AKS Automatic 跑第一条真实 DEV GitOps Release
8. 扩展 Redis / Storage / Key Vault / Database 等 IaC Catalog 产品

---

平台最终目标是一条可治理的 Paved Road（标准铺装路径）：

```text
研发声明需求
 -> 平台标准化执行
 -> 机器自动校验
 -> 人审核真实变化
 -> 受控创建/发布
 -> 自动验证
 -> 可审计回滚
```
