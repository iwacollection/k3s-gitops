# GitOps / Flux CD Control Plane

本目录是 Kubernetes CD（持续交付）最终写控制面。

核心原则：

```text
CI produces artifact
Release Request promotes digest
Git records desired state
Flux reconciles AKS
```

## 为什么不用 CI 直接 kubectl

普通 CI 只需要读取代码、访问依赖、构建和推送 ACR，不应该长期持有 PROD AKS Admin 权限。

```text
Push CD:
CI -> kubeconfig -> AKS

Target GitOps:
CI -> ACR -> Release Request -> GitOps PR -> Git -> Flux -> AKS
```

Flux 是 Pull-based GitOps Controller（拉取式 GitOps 控制器）：控制器运行在集群侧，主动读取 Git Desired State（期望状态），并持续把 Kubernetes 实际状态协调回 Git 声明状态。

## 目录职责

```text
gitops/
├── contracts/                   # GitOps 硬规则
├── clusters/                    # 每个 AKS 集群的 Flux 绑定契约/Bootstrap
├── infrastructure/              # 集群级共享 Kubernetes 基础设施
├── apps/                        # 应用 Base Manifest/Kustomize
└── environments/
    ├── dev/                     # DEV Desired State
    ├── test/                    # TEST Desired State
    └── prod/                    # PROD Desired State
```

## Environment Root

每个环境都有一个根 `kustomization.yaml`。

Release Promotion 不直接执行 `kubectl apply`，而是生成/更新：

```text
environments/<env>/apps/<application>/kustomization.yaml
```

根 Kustomization 再引用这些应用 Overlay。

## Artifact Identity

环境状态只接受不可变 Artifact Digest：

```text
example.azurecr.io/payment-api@sha256:...
```

禁止用 `latest` 作为环境期望状态。

## Promotion

允许的默认路径：

```text
build -> dev -> test -> prod
```

同一个 Digest 逐级晋级，不重新 Build。

Release Request -> `promotion/render_gitops_overlay.py` -> Environment Overlay -> Protected GitOps PR。

## Flux Binding

当前 Lab 目标：

```text
AKS: k8s-test-cicd
Resource Group: group-test
Cluster Type: managedClusters
Flux Extension: microsoft.flux
Repository: iwacollection/k3s-gitops
Branch after framework merge: main
```

Azure Flux Configuration 分成两个 Kustomization：

```text
infra
  path: ./enterprise-cicd/gitops/infrastructure

apps-dev
  path: ./enterprise-cicd/gitops/environments/dev
  dependsOn: infra
```

生产环境应为各环境/集群独立配置，不能让 DEV Flux 路径误指向 PROD。

## Approval Boundary

DEV 可以在策略允许时自动 Promotion PR 合并；TEST 需要测试门禁；PROD 必须使用受保护分支/Environment、Reviewer 和串行发布锁。

Approval 发生在 Git Desired State 变化之前，不把审批做成应用 Pipeline 可以自行删除的一个 YAML step。

## Verification

Flux Reconcile 只是“配置已经应用”的证据，不等于业务恢复成功。CD 后续必须继续验证：

- Flux/Kustomization Ready
- Kubernetes Deployment Available
- Pod Ready
- Service/Ingress 可达
- Smoke Test
- Error Rate / P99 / SLO

失败时回滚到 `previous-approved-digest`，不是重新 Build。

## Bootstrap Safety

`clusters/aks-automatic-lab/bootstrap-flux-aks.sh` 默认只打印计划；只有显式传 `--apply` 才允许修改 Azure/AKS。

控制面 PR 本身不会自动安装 Flux，也不会自动部署业务到 AKS。
