# Azure Enterprise IaC + CI/CD Platform

> Microsoft Azure 企业级 IaC（Infrastructure as Code，基础设施即代码）+ CI/CD 平台控制面。
>
> 核心原则：**Platform owns implementation; developers submit intent.** 平台团队维护 Terraform、Pipeline、Build Image、Policy、发布策略和权限边界；研发团队提交需求声明，不重复实现平台能力。

## 1. 当前开发位置

企业平台 V1 当前位于：

```text
Repository: iwacollection/k3s-gitops
Branch:     design/azure-enterprise-control-plane-v1
PR:         #5 (Draft)
```

`main` 仍是稳定基线。本文描述的是 Draft PR #5 中的控制面实现。

## 2. 总体工作流

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
   +-- Application Code
   |       -> CI Build Catalog
   |       -> Test / Security
   |       -> SBOM / Provenance / Sign
   |       -> Immutable Digest
   |       -> ACR
   |
   +-- Release Request
           -> Promotion Policy
           -> Protected GitOps PR
           -> Flux
           -> AKS
           -> Verify
           -> Approved Ledger or Rollback PR
```

## 3. IaC 管理模型

研发默认**不直接写 `azurerm_*`**，只提交 `InfrastructureRequest`。平台维护标准产品目录：

```text
iac-catalog/services/<service>/<version>/
├── catalog.json
├── request.schema.json
├── defaults.json
├── policy.json
└── request.example.json
```

每个产品映射到平台维护的 Terraform Module 和 Root Stack。请求通过 Schema、环境 Policy、平台命名和网络/身份绑定后，才被编译成 `.auto.tfvars.json`。

### 当前 IaC Service Catalog

| Product | Lifecycle | 关键生产约束 |
|---|---|---|
| `acr/v1` | active | 受控 SKU、不可变 Artifact 目标 |
| `storage/v1` | active | Shared Key 禁用、版本化/保留策略、生产复制策略 |
| `managed-identity/v1` | active | Workload Identity 边界 |
| `key-vault/v1` | active | Public Network Disabled、Private Endpoint、Private DNS、Purge Protection |
| `service-bus/v1` | active | Premium-only Private Endpoint、Local Auth Disabled、Public Network Disabled |
| `managed-redis/v1` | active | Azure Managed Redis、Encrypted、Access Keys Disabled、Private Endpoint/DNS |
| `postgresql-flexible/v1` | preview | VNet Delegation、Private DNS、Entra-only；PROD 等待平台 DBA Entra Admin Binding |

### Terraform State

平台 Stack 按生命周期和 Blast Radius 独立 State。研发 Catalog Request 使用：

```text
catalog/{environment}/{service}/{request}.tfstate
```

一个申请一个 State/Lock，不让多个业务资源互相覆盖或扩大变更半径。

### Plan / Apply 分权

```text
DEV   tf-plan-dev   / tf-apply-dev
TEST  tf-plan-test  / tf-apply-test
PROD  tf-plan-prod  / tf-apply-prod
```

使用 OIDC/WIF，禁止一个万能 Contributor Identity 管理所有环境，禁止 PR Pipeline 直接 Apply。

## 4. Azure Network Foundation

平台 Connectivity Stack 已具备：

```text
VNet / Subnet
NSG
Route Table / UDR
NAT Gateway
Private DNS + VNet Link
Private Endpoint + DNS Zone Group
RBAC Role Assignment
```

研发不填写原始 VNet/Subnet/DNS Resource ID。`contracts/environment-bindings.json` 将 `dev/test/prod` 映射到平台拥有的网络资源名字。

标准网络槽位包括：

```text
snet-aks
snet-private-endpoints
snet-postgresql   # delegated to Microsoft.DBforPostgreSQL/flexibleServers
```

## 5. AKS Platform

标准 AKS Module / Root Stack 已实现并通过 AzureRM 4.81 validate：

- Standard tier
- private cluster option
- local account disabled
- Azure RBAC
- OIDC issuer
- Workload Identity
- Azure Policy
- Azure CNI
- Standard Load Balancer
- Key Vault CSI secret rotation
- system node pool autoscaling
- ACR Pull RBAC via kubelet identity

当前 Lab 继续复用已有 `k8s-test-cicd` AKS Automatic；Terraform 标准 AKS 模块不会自动替换现有实验集群。

## 6. Data Platform

### Azure Managed Redis

标准产品使用 `azurerm_managed_redis`，默认关闭公共网络，通过 Private Endpoint 接入，并关闭 Access Key Authentication、强制 Encrypted client protocol。生产策略要求 HA 和受控 SKU。

### PostgreSQL Flexible Server

标准产品使用 VNet-integrated Flexible Server：

- Delegated Subnet
- Private DNS
- Public Network Disabled
- System Assigned Identity
- Microsoft Entra Authentication Enabled
- Password Authentication Disabled
- Backup/HA 由环境 Policy 约束

当前 V1 的 DEV/TEST 模板可用；PROD 明确阻断，直到平台级 DBA Entra Administrator Binding 被配置，而不是让研发自己填管理员账号。

## 7. Observability Platform

`platform/observability` Root Stack 已建立：

- Log Analytics Workspace
- Azure Monitor Workspace（Managed Prometheus 基础）
- Local Auth Disabled
- Retention / Quota 受控

后续 AKS Monitor/Managed Prometheus 关联和 Managed Grafana 属于平台集成层，而不是每个应用自行创建。

## 8. CI Build Platform

CI 使用 GitHub Actions Reusable Workflow。单应用内部使用 `needs` DAG，Monorepo/多应用使用外层 `matrix`。

```text
resolve
  -> source-scan + build-test
  -> image-build
  -> image-scan + SBOM
  -> sign
  -> release-evidence
```

当前标准 Build Profile：

| Language | Profile | Build Image |
|---|---|---|
| Java | `java/springboot-maven-v1` | `java21-maven:v1` |
| Python | `python/python-uv-v1` | `python-uv:v1` |
| Go | `go/go-service-v1` | `go-builder:v1` |
| C++ | `cpp/cmake-conan-v1` | `cpp-cmake-conan:v1` |

统一生命周期：

```text
prepare -> verify -> package
```

CI 只负责产生可信制品，不持有 Terraform Apply 或生产 AKS 写权限。

## 9. Dependency / Cache

平台统一 Maven / PyPI / Go Proxy / Conan Remote 策略。Cache Key 必须绑定 Lock File、Build Profile、Build Image Version 和 Architecture，避免多项目共享可写缓存导致污染、ABI 不一致和并发损坏。

## 10. Artifact 与供应链安全

```text
Source Commit
 -> Build Profile
 -> Build Image Version
 -> Tests
 -> Source/Container Scan
 -> SBOM
 -> BuildKit Provenance
 -> Cosign Signature
 -> ACR sha256 Digest
```

遵守 **Build Once, Promote Same Digest**。DEV/TEST/PROD 使用同一 Digest，不允许生产重新 Build。

## 11. CD / GitOps

CI 到 ACR 即停止。Release Request 驱动环境晋级：

```text
Artifact Digest
 -> Release Request
 -> Promotion Policy
 -> GitOps Desired State PR
 -> Flux
 -> AKS
 -> Read-only Observation
 -> Verification
 -> Approved Ledger / Rollback PR
```

环境只允许：

```text
build -> dev -> test -> prod
```

`rolling-v1` 已 execution-ready。Canary/Blue-Green 只保留 Catalog，直到真实 progressive-delivery controller 接入前不会伪装成可执行策略。

Rollback 使用 last approved digest，不重新 Build。

## 12. Azure DevOps IaC Governance

Azure DevOps 负责 Terraform / Environment Governance：

- Request discovery
- PR Terraform Plan
- Plan Evidence
- Merge-time re-plan
- Exact saved-plan Apply
- 固定 DEV/TEST/PROD Plan/Apply Service Connection
- Required Template
- Branch Control
- Approval
- Exclusive Lock

Service Connection 不使用运行时变量动态拼接，避免授权边界在 Pipeline 执行时漂移。

## 13. GitHub Actions 与 Azure DevOps 分工

```text
GitHub Actions -> Application CI
Azure DevOps   -> IaC / Environment Governance
Flux           -> Kubernetes write/reconciliation plane
```

同一职责只保留一个最终写控制面，禁止 GitHub Actions 与 Azure DevOps 同时直接修改 PROD AKS。

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
│   └── observability/
└── stacks/
    ├── platform/
    │   ├── identity/
    │   ├── acr/
    │   ├── connectivity/
    │   ├── aks/
    │   └── observability/
    └── workloads/
        ├── storage/
        ├── key-vault/
        ├── managed-identity/
        ├── service-bus/
        ├── managed-redis/
        └── postgresql-flexible/
```

## 15. 自动验证

平台代码自己必须通过治理测试，而不是等第一个研发项目踩坑：

- Control Contract Validate
- Framework Structure Validate
- Platform Catalog Validate
- Terraform Framework Validate
- Build Platform Validate
- Build Profile Smoke
- GitOps Platform Validate
- Azure DevOps Platform Validate
- CD Closure Validate

Terraform Root Stack 验证已经改为 **Matrix 并行**，当前 11 个 Root Stack 可同时 `init -backend=false + validate`，避免第一个失败阻断其余问题发现。

验证 Workflow 明确禁止执行 `terraform apply`，Flux Bootstrap 和真实 Azure 资源创建也保持显式受保护操作。

## 16. 研发日常入口

基础设施：

```text
Infrastructure Request -> Plan -> Review -> Protected Apply
```

代码：

```text
Application Definition -> Standard Reusable CI -> Immutable Artifact
```

发布：

```text
Release Request -> Promotion -> GitOps -> Flux -> Verify -> Evidence/Rollback
```

研发不需要分别学习怎么实现 Azure Provider Resource、GitHub Pipeline、Azure DevOps Apply 和生产 `kubectl`；这些属于平台维护能力。

## 17. V1 剩余收口重点

- PostgreSQL PROD Entra DBA Binding
- AKS 与 Log Analytics / Managed Prometheus 的标准关联
- Managed Grafana（可选）
- Diagnostic Settings / Resource Locks / 更细 Policy Baseline
- 将版本化 Platform Build Images 正式发布到 ACR
- 用现有 Lab AKS 跑通第一条受控 DEV Promotion + Observation

在这些受保护控制面完成前，PR #5 保持 Draft，不自动创建额外 AKS 或生产资源。
