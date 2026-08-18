# Azure Enterprise IaC + CI/CD Platform

> Microsoft Azure 企业级 IaC（Infrastructure as Code，基础设施即代码）+ CI/CD 平台控制面。
>
> 核心原则：**Platform owns implementation; developers submit intent.** 平台团队维护 Terraform、Pipeline、Build Image、Policy、发布策略、身份和权限边界；研发提交标准化需求，不重复实现平台能力。

## 1. 当前状态

```text
Repository: iwacollection/k3s-gitops
Platform branch: design/azure-enterprise-control-plane-v1
Platform PR: #5 (Draft)
DEV desired-state branch: gitops/dev
TEST desired-state branch: gitops/test
PROD desired-state branch: gitops/prod
```

`main` 仍是稳定基线，PR #5 暂不合并。

当前 V1 不再只是“框架代码 Ready”：**真实 Azure DEV E2E 已经完成并验证通过。**

```text
GitHub OIDC
  -> Azure
  -> ACR
  -> governed build image
  -> Application CI
  -> immutable application digest
  -> Release Request
  -> protected GitOps PR
  -> gitops/dev
  -> Flux
  -> AKS
  -> Deployment Ready
  -> Endpoint Ready
  -> exact digest verification
```

详细证据：

`enterprise-cicd/activation/DEV-ACTIVATION-EVIDENCE.md`

## 2. 平台职责边界

```text
Developer
   |
   +-- Infrastructure Request
   |       -> IaC Service Catalog
   |       -> Schema / Defaults / Policy
   |       -> Terraform Plan
   |       -> Review
   |       -> Protected Apply
   |       -> Azure
   |
   +-- Application Definition + Source Code
   |       -> Build Profile
   |       -> Standard Build Image @ sha256
   |       -> Test / Security
   |       -> SBOM / Provenance / Sign
   |       -> Immutable Application Digest
   |       -> ACR
   |
   +-- Release Request
           -> Promotion Policy
           -> Protected Desired-State PR
           -> Flux
           -> AKS
           -> Read-only Verification
```

最终写控制面保持单一：

```text
GitHub Actions -> Application CI
Azure DevOps   -> IaC / Environment Governance
Flux           -> Kubernetes write/reconciliation plane
```

CI Workflow 不直接 `kubectl apply/create`，也不直接 Helm install/upgrade 生产工作负载。

## 3. IaC 管理模型

研发默认不直接写 `azurerm_*`，而是提交 `InfrastructureRequest`：

```text
iac-catalog/services/<service>/<version>/
├── catalog.json
├── request.schema.json
├── defaults.json
├── policy.json
└── request.example.json
```

请求经过 Schema、Defaults、环境 Policy、Naming、Network Binding、Identity Binding 后，由平台 Renderer 编译成 Terraform 输入。

### IaC Service Catalog V1

| Product | Lifecycle | 关键生产约束 |
|---|---|---|
| `acr/v1` | active | 受控 SKU、Artifact Registry 基线 |
| `storage/v1` | active | Shared Key Disabled、Private Endpoint、Diagnostics、生产 Lock |
| `managed-identity/v1` | active | Workload Identity / RBAC 边界 |
| `key-vault/v1` | active | Public Network Disabled、Private Endpoint/DNS、Purge Protection、Diagnostics |
| `service-bus/v1` | active | Premium-only Private Networking、Local Auth Disabled、Diagnostics |
| `managed-redis/v1` | active | Azure Managed Redis、Access Keys Disabled、Private Endpoint/DNS、Diagnostics |
| `postgresql-flexible/v1` | DEV/TEST active | VNet Delegation、Private DNS、Entra-only；PROD 等待真实 DBA Entra Group Binding |

研发不填写平台 VNet/Subnet/DNS Resource ID。环境资源通过：

`contracts/environment-bindings.json`

统一绑定。

## 4. Terraform State / Plan / Apply

Catalog Request 独立 State：

```text
catalog/{environment}/{service}/{request}.tfstate
```

一个请求一个 State/Lock，降低 Blast Radius（爆炸半径；人话：一次错误变更最多影响多大范围）。

身份分离：

```text
DEV   tf-plan-dev   / tf-apply-dev
TEST  tf-plan-test  / tf-apply-test
PROD  tf-plan-prod  / tf-apply-prod
```

治理规则：

- PR 只 Plan，不 Apply
- Merge 后重新 Plan
- Apply 使用精确 Saved Plan
- WIF/OIDC（Workload Identity Federation，工作负载联合身份；人话：不用长期 Client Secret）
- PROD Environment Approval
- Branch Control
- Required Template
- Exclusive Lock
- 禁止一个万能 Contributor Identity 管全部环境

## 5. Network Foundation

平台 Connectivity Stack 已覆盖：

```text
VNet
Subnet
NSG
Route Table / UDR
NAT Gateway
Private DNS
VNet Link
Private Endpoint
DNS Zone Group
RBAC Role Assignment
```

标准网络槽位包括：

```text
snet-aks
snet-private-endpoints
snet-postgresql
```

## 6. AKS Platform

标准 AKS Module / Root Stack 包含：

- Standard tier
- private cluster option
- local account disabled
- Azure RBAC
- OIDC issuer
- Workload Identity
- Azure Policy
- Azure CNI
- Standard Load Balancer
- Key Vault CSI + rotation
- system node pool autoscaling
- ACR Pull via kubelet identity
- Container Insights
- Managed Prometheus

当前真实 DEV 复用已有：

```text
Resource Group: group-test
AKS:            k8s-test-cicd
Namespace:      cicd-dev
```

标准 Terraform AKS Module 不会自动替换这个实验集群。

## 7. Observability Platform

平台已包含：

- Log Analytics Workspace
- Azure Monitor Workspace
- Container Insights DCR/DCRA
- Managed Prometheus DCE/DCR/DCRA
- Generic Diagnostic Setting Module
- platform-owned `diagnostic-categories.json`
- Storage / Key Vault / Service Bus / Redis Diagnostic Settings

Managed Grafana 属于 post-V1 可选能力。

## 8. CI Build Platform

GitHub Actions 使用 Reusable Workflow + `needs` DAG；多项目/Monorepo 可在外层使用 Matrix。

当前标准 Build Profile：

| Language | Profile | Build Image |
|---|---|---|
| Java | `java/springboot-maven-v1` | `java21-maven:v1` |
| Python | `python/python-uv-v1` | `python-uv:v1` |
| Go | `go/go-service-v1` | `go-builder:v1` |
| C++ | `cpp/cmake-conan-v1` | `cpp-cmake-conan:v1` |

Build 生命周期：

```text
prepare -> verify -> package
```

Application CI v2：

```text
resolve
  -> source-scan + build-test
  -> image-build
  -> image-scan + SBOM
  -> sign
  -> release-evidence
```

### Monorepo / 多服务

Application Definition 支持 `sourcePath`，CI 不再假设代码一定在仓库根目录。

### Dependency Cache

Cache 与源码工作区物理隔离：

```text
Source:       /workspace
Cache:        $RUNNER_TEMP/platform-cache/<application>/<profile>
Build Context isolated separately
```

这避免 Maven/PyPI/Go/Conan 缓存污染源码、打包产物或并发构建。

## 9. 真实 Platform Build Images

四套标准构建镜像已经真实发布到：

`acrcicdc12c3a3699d8.azurecr.io`

并通过 immutable digest Gate：

| Image | Digest |
|---|---|
| `build/java21-maven:v1` | `sha256:02ea4848f16f7d70811bcd1c66b78354648510341d835ab06154eb3052dcbaf6` |
| `build/python-uv:v1` | `sha256:f6d63e38fbb3bd2e1edae918afbc1e3abafdb0f4dc961449d33f5c2d8722c02d` |
| `build/go-builder:v1` | `sha256:813d1bcbe71bb2bdaebcb622c4af65d5a02ee6196e98c0aed3535109f51f5ace` |
| `build/cpp-cmake-conan:v1` | `sha256:8864bafcd66839cc76577f450c4988b0d06d4e3be6bcf3ba6b29c332faf6fb6e` |

应用 CI 运行时不是只信任 `:v1`，而是先从 ACR 解析它的 `sha256`，再使用：

```text
build-image@sha256:...
```

作为真实编译环境。

## 10. Artifact / Supply Chain Security

```text
Source Commit
 -> Build Profile
 -> Build Image @ sha256
 -> Tests
 -> Source Scan
 -> Image Build
 -> Container Scan
 -> SBOM
 -> BuildKit Provenance
 -> Cosign OIDC Signature
 -> ACR sha256 Digest
```

坚持 **Build Once, Promote Same Digest**。

安全 Gate 在真实 smoke CI 中曾检测并阻断 Debian runtime image 的可修复 HIGH 漏洞；平台升级基础镜像依赖后重新扫描通过，没有把 HIGH/CRITICAL Gate 改成 warning。

## 11. CD / GitOps

Release 只接受 immutable digest：

```text
Build Artifact
 -> Release Request
 -> Promotion Policy
 -> target Desired-State baseline
 -> Promotion branch
 -> protected GitOps PR
 -> merge
 -> Flux reconcile
 -> AKS
 -> read-only verify
```

允许的环境转换：

```text
build -> dev -> test -> prod
```

环境 Desired-State 分支：

```text
gitops/dev
gitops/test
gitops/prod
```

Promotion 分支必须从目标 Desired-State 分支创建，禁止从平台开发分支直接向 `gitops/dev` 带入无关代码。

## 12. Real DEV E2E

验证应用：

`platform-smoke-api`

最终全绿 CI Artifact：

```text
Repository:
acrcicdc12c3a3699d8.azurecr.io/apps/platform-smoke-api

Digest:
sha256:b0faf7a8f90618cd7a6b081085d3af3ca666afa015aac9827f71cf198816e2ba
```

CI Gate：

```text
resolve          PASS
source-scan      PASS
build-test       PASS
image-build      PASS
image-scan       PASS
SBOM             PASS
Cosign sign      PASS
release-evidence PASS
```

真实 Release Request：

`release-requests/platform-smoke-api-to-dev.json`

Promotion PR #6：

```text
base: gitops/dev
commits: 1
changed files: 3
GitOps Platform Validate: PASS
CD Closure Validate: PASS
Framework Structure Validate: PASS
```

合并 commit：

`37ae91eed8e2c40038524d1b524111056dc637ce`

Flux / AKS 最终验证：

```text
Flux compliant:       true
Deployment:           platform-smoke-api
Namespace:            cicd-dev
Desired replicas:     1
Available replicas:   1
Ready replicas:       1
EndpointSlices:       1
Ready endpoints:      1
Exact digest:         PASS
Verification result:  passed
```

实际运行镜像：

`acrcicdc12c3a3699d8.azurecr.io/apps/platform-smoke-api@sha256:b0faf7a8f90618cd7a6b081085d3af3ca666afa015aac9827f71cf198816e2ba`

## 13. Azure DevOps IaC Governance

Azure DevOps 负责 Terraform / Environment Governance：

- IaC Request discovery
- PR Terraform Plan
- Plan Evidence
- Merge-time re-plan
- Exact saved-plan Apply
- 固定 DEV/TEST/PROD Plan/Apply Service Connection
- WIF/OIDC
- Required Template
- Branch Control
- Approval
- Exclusive Lock

Service Connection 不允许通过运行时变量动态拼接。

## 14. Terraform 工程结构

```text
terraform/
├── bootstrap/
├── state/
├── modules/
│   ├── resource-group/
│   ├── managed-identity/
│   ├── acr/
│   ├── network/
│   ├── network-security-group/
│   ├── route-table/
│   ├── nat-gateway/
│   ├── private-dns/
│   ├── private-endpoint/
│   ├── role-assignment/
│   ├── aks/
│   ├── storage-account/
│   ├── key-vault/
│   ├── service-bus/
│   ├── managed-redis/
│   ├── postgresql-flexible/
│   ├── diagnostic-setting/
│   └── observability/
└── stacks/
    ├── platform/
    │   ├── identity/
    │   ├── acr/
    │   ├── connectivity/
    │   ├── aks/
    │   ├── observability/
    │   └── aks-observability/
    └── workloads/
        ├── storage/
        ├── key-vault/
        ├── managed-identity/
        ├── service-bus/
        ├── managed-redis/
        └── postgresql-flexible/
```

## 15. 自动验证

平台自身持续通过：

- Control Contract Validate
- Framework Structure Validate
- Terraform Framework Validate
- Platform Catalog Validate
- Build Platform Validate
- Build Profile Smoke
- GitOps Platform Validate
- Azure DevOps Platform Validate
- CD Closure Validate
- Platform Activation Readiness
- Azure DEV Activation Preflight
- Platform Build Images Verify
- Platform Smoke Application CI
- Platform Smoke DEV Observe

Terraform 使用 **12 Root Stack Matrix 并行**执行 `init -backend=false + validate`，避免串行失败遮蔽其余问题。

Validation Workflow 明确禁止 `terraform apply`。

## 16. 研发日常入口

基础设施：

```text
Infrastructure Request -> Plan -> Review -> Protected Apply
```

代码：

```text
Application Definition -> Standard Build Profile -> Reusable CI -> Immutable Artifact
```

发布：

```text
Release Request -> Protected GitOps PR -> Flux -> Read-only Verify
```

研发不需要重复维护 Terraform Provider Resource、CI Pipeline、生产 Kubernetes 写权限和环境策略。

## 17. 下一阶段

DEV V1 已完成真实激活。下一阶段重点不再是继续堆 DEV Module：

1. 激活 TEST Azure identity / environment binding。
2. 用 **同一个 `platform-smoke-api` digest** 做 `dev -> test`，验证 Build Once / Promote Same Digest。
3. 配置真实 PostgreSQL PROD Entra DBA Group Object ID + principal name；未配置前 PROD 保持硬阻断。
4. 激活 PROD Protected Environment / Approval / Identity。
5. 用同一 digest 做 `test -> prod`。
6. 做 rollback / failed-health drill，验证 previous-approved-digest 回滚闭环。
7. 可选 post-V1：Managed Grafana、真实 Canary/Blue-Green Controller。

PR #5 在平台评审完成前继续保持 Draft，不自动合并到 `main`。
