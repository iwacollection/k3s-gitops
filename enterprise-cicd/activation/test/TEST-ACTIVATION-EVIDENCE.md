# TEST 环境真实激活与验证证据

> 状态：**已完成**  
> 环境：TEST  
> 模式：共享实验 AKS 上的独立逻辑环境  
> 最终结果：**DEV -> TEST 使用同一个不可变镜像摘要完成发布并验证通过**

---

## 1. 最终结论

TEST 环境已经完成真实 Azure / AKS / GitOps 激活，并完成第一条应用的真实 DEV -> TEST 晋级。

本次验证不是重新构建一个 TEST 镜像，而是把 DEV 已经验证过的同一个镜像摘要继续晋级到 TEST：

```text
acrcicdc12c3a3699d8.azurecr.io/apps/platform-smoke-api
@sha256:b0faf7a8f90618cd7a6b081085d3af3ca666afa015aac9827f71cf198816e2ba
```

这证明平台当前已经实现：

```text
Build Once
   ↓
DEV 验证
   ↓
同一个 Digest
   ↓
TEST 发布
   ↓
TEST 运行态验证
```

---

## 2. TEST 逻辑边界

当前实验环境为了控制 Azure 成本，DEV 与 TEST 复用同一套物理 AKS 和 ACR，但逻辑控制边界独立。

```text
共享物理资源：
AKS：group-test / k8s-test-cicd
ACR：acrcicdc12c3a3699d8.azurecr.io

DEV：
GitHub Environment：dev
GitOps Branch：gitops/dev
Namespace：cicd-dev
Flux Configuration：enterprise-cicd

TEST：
GitHub Environment：test
GitOps Branch：gitops/test
Namespace：cicd-test
Flux Configuration：enterprise-cicd-test
```

这不是生产环境最终物理隔离模型，而是实验环境下用于验证企业控制逻辑的低成本方案。

---

## 3. TEST 独立 OIDC 身份

TEST 没有复用 DEV 的 Azure 身份，而是建立独立用户分配托管身份（UAMI）：

```text
identity：k3s-gitops-test-uami
clientId：f0a007c9-7e56-47bd-9b64-9e1c6b92b816
principalId：ec01ea19-67ac-436f-ad28-73f568572769
OIDC subject：repo:iwacollection/k3s-gitops:environment:test
```

TEST principal 与 DEV principal 不同，避免 DEV / TEST 权限边界混用。

GitHub Actions 通过 OIDC 临时登录 Azure，不保存长期 Azure Client Secret。

---

## 4. TEST 最小权限模型

TEST 身份仅获得以下权限：

```text
Reader
  -> 仅 AKS Resource Scope

Azure Kubernetes Service Cluster User Role
  -> 仅 AKS Resource Scope

Azure Kubernetes Service RBAC Reader
  -> 仅 cicd-test Namespace Scope

AcrPull
  -> 仅 ACR Scope
```

明确没有：

```text
Owner
Contributor
User Access Administrator
Azure Kubernetes Service RBAC Writer
Azure Kubernetes Service RBAC Admin
AcrPush
cluster-admin
```

真实 Gate 验证：

```text
读取 Deployment：      yes
读取 EndpointSlice：   yes
创建 Deployment：      no
修改 Deployment：      no
删除 Deployment：      no
读取已批准 ACR Digest：yes
```

Azure 对写操作的真实拒绝信息：

```text
no - User does not have access to the resource in Azure.
```

因此 TEST GitHub Actions 只能观察和验证，不能绕过 GitOps 直接部署。

---

## 5. TEST Flux

TEST 使用独立 Flux Configuration：

```text
name：enterprise-cicd-test
configuration namespace：enterprise-cicd-test
repository：https://github.com/iwacollection/k3s-gitops
branch：gitops/test
kustomization：apps-test
path：./enterprise-cicd/gitops/environments/test
```

TEST Flux 不重复管理共享 `gitops/infrastructure`，避免 DEV Flux 与 TEST Flux 同时争抢共享基础设施对象。

最终状态：

```text
Flux provisioningState：Succeeded
Flux complianceState：Compliant
GitRepository：Compliant
apps-test Kustomization：Compliant
```

---

## 6. DEV -> TEST 发布链

真实 TEST Release Request：

```text
enterprise-cicd/release-requests/platform-smoke-api-to-test.json
```

来源：

```text
enterprise-cicd/release-requests/platform-smoke-api-to-dev.json
```

平台已经增加不可变制品血缘 Gate：

```text
dev -> test
必须声明 sourceReleaseRequest
    ↓
application 必须相同
source.to 必须等于 dev
artifactRepository 必须相同
artifactDigest 必须完全相同
```

因此 TEST 无法偷偷重新 Build 或换一个 tag / digest。

---

## 7. GitOps TEST Promotion

第一次 TEST Promotion 使用受保护的 `gitops/test` Desired State 分支。

正式 Promotion PR：

```text
PR #7
目标：gitops/test
```

PR 只修改 TEST Desired State：

```text
enterprise-cicd/gitops/environments/test/apps/platform-smoke-api/kustomization.yaml
enterprise-cicd/gitops/environments/test/apps/platform-smoke-api/release-evidence.json
enterprise-cicd/gitops/environments/test/kustomization.yaml
```

没有 Terraform 修改，没有平台代码进入 Desired State，也没有 CI 直接执行 `kubectl apply`。

PR #7 合并后第一版 TEST commit：

```text
88483a338be1189c2fe607b31a991f0756b7d7a0
```

---

## 8. 本次真实故障：ARM Namespace 与 Flux 所有权冲突

第一次 Flux reconcile 时，GitRepository 已经成功同步最新 `gitops/test`，但 `apps-test` 为 `Non-Compliant`。

真实错误：

```text
Namespace/cicd-test dry-run failed:
admission webhook "aks-namespace-validating-webhook.azmk8s.io" denied the request:
Updating/deleting namespace cicd-test labels is not allowed because it is managed by ARM.
Please update this namespace through ARM api.
```

### 原因

`cicd-test` 已经属于 Azure ARM 管理的 Namespace，但 TEST Kustomization 同时引用了：

```text
namespace.yaml
```

因此形成：

```text
Azure ARM
   └── 管理 cicd-test Namespace

Flux
   └── 又尝试管理 cicd-test Namespace
```

这是典型的多控制器资源所有权冲突。

### 正确修复

没有给 Flux 更大的管理员权限，也没有删除 Azure 管理的 Namespace。

而是明确资源所有权：

```text
DEV： namespaceManagement = gitops
TEST：namespaceManagement = arm
```

TEST Flux 只负责：

```text
Deployment
Service
后续 TEST namespace 内业务资源
```

不再负责修改 `cicd-test` Namespace 本身。

修复 PR：

```text
PR #8
```

PR #8 仅：

```text
从 TEST environment root 移除 namespace.yaml 引用
在 release evidence 中记录 namespaceManagement=arm
```

应用 digest 没有改变。

最终修复后的 `gitops/test` commit：

```text
bb5b5400b7cedc35f0ed399c3fa450bcc4515df8
```

平台 Promotion Renderer 也同步增加 Namespace 所有权 Contract，防止以后再次把 ARM Namespace 加回 Flux Desired State。

---

## 9. TEST 最终运行态

最终真实 Azure / AKS 快照：

```text
Flux：Compliant
GitRepository：Compliant
apps-test：ReconciliationSucceeded
Flux synced commit：bb5b5400b7cedc35f0ed399c3fa450bcc4515df8
```

Deployment：

```text
namespace：cicd-test
name：platform-smoke-api
desired replicas：1
available replicas：1
ready replicas：1
updated replicas：1
```

Pod：

```text
Ready：1/1
Status：Running
Restart：0
```

EndpointSlice：

```text
items：1
readyEndpoints：1
```

真实运行镜像：

```text
acrcicdc12c3a3699d8.azurecr.io/apps/platform-smoke-api@sha256:b0faf7a8f90618cd7a6b081085d3af3ca666afa015aac9827f71cf198816e2ba
```

与 DEV 已验证 Digest 完全一致。

---

## 10. 正式 Observation Gate

GitHub Actions：

```text
Platform Smoke TEST Observe
run：32226070472
```

最终 Verification：

```json
{
  "environment": "test",
  "gitopsCommit": "bb5b5400b7cedc35f0ed399c3fa450bcc4515df8",
  "artifact": {
    "digest": "sha256:b0faf7a8f90618cd7a6b081085d3af3ca666afa015aac9827f71cf198816e2ba",
    "sameDigestFromDev": true
  },
  "status": {
    "desiredReplicas": 1,
    "availableReplicas": 1,
    "readyReplicas": 1,
    "readyEndpoints": 1,
    "fluxCompliant": true,
    "mutationAccess": false,
    "result": "passed"
  }
}
```

验证 Artifact：

```text
platform-smoke-test-verification-32226070472
Artifact ID：9355561452
Artifact ZIP SHA256：feaedf9e5a8829466ff311d9b8eeafb4ade6b814788e03f7f162771bfcef07b3
```

---

## 11. 当前完整制品晋级状态

```text
应用源码
   ↓
标准 Python Build Profile
   ↓
编译 / pytest
   ↓
源码安全扫描
   ↓
应用容器 Build
   ↓
容器漏洞扫描
   ↓
SBOM
   ↓
Provenance
   ↓
Cosign OIDC 签名
   ↓
ACR immutable digest
   ↓
DEV Release Request
   ↓
gitops/dev
   ↓
Flux
   ↓
DEV Verification ✅
   ↓
同一个 Digest
   ↓
TEST Release Request
   ↓
gitops/test
   ↓
enterprise-cicd-test Flux
   ↓
TEST Verification ✅
```

当前已经真实证明：

**Build Once，Promote Same Digest。**

---

## 12. 下一阶段

TEST 已完成，不再继续为 TEST 堆临时激活代码。

下一阶段应进入 PROD Readiness，但仍保持默认不创建生产收费资源：

```text
PROD Inventory
  -> PROD 身份边界
  -> PROD GitHub Environment 审批
  -> PROD 基础设施 / AKS / ACR / 网络差异
  -> PostgreSQL DBA Group 硬 Gate
  -> PROD Flux / GitOps 策略
  -> test -> prod 同 Digest 晋级
  -> 生产验证 / 回滚
```

在 PROD 身份、数据库 DBA Group、审批策略和真实资源边界没有准备完成前，平台继续保持生产阻断。
