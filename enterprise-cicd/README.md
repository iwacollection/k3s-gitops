# Azure 企业级 IaC + CI/CD 平台

> 这是一套运行在 Microsoft Azure 上的企业级基础设施与应用交付控制平台。
>
> 它不是单独的一条 GitHub Actions 流水线，也不是一堆 Terraform 文件，而是把 **基础设施申请、代码编译、依赖与构建环境、制品安全、环境晋级、Kubernetes 发布、身份权限、审批和验证** 统一管理起来。
>
> 核心原则：**平台团队维护标准能力，研发人员只提交业务需求和必要变量。**

---

## 1. 先用一句人话说明这套平台

研发人员以后不应该自己复制一套 Terraform、自己写一套 CI、自己拿 Kubernetes 管理员权限然后直接发布。

正确的企业流程应该是：

```text
我要一个 Azure 资源
    -> 填标准基础设施申请
    -> 平台规则检查
    -> Terraform 只生成变更计划
    -> 审核
    -> 受控执行
    -> Azure 创建/修改资源

我要提交应用代码
    -> 平台识别 Java / Python / Go / C++ 构建标准
    -> 使用平台维护的标准构建镜像
    -> 编译 / 测试 / 安全扫描
    -> 生成不可变镜像
    -> 推送 ACR

我要发布
    -> 提交发布申请
    -> 只能晋级已经构建好的同一个镜像摘要
    -> 修改目标环境 Git 状态
    -> 审核并合并
    -> Flux 自动同步 AKS
    -> 只读验证
```

最终形成三条清晰链路：

```text
基础设施：需求 -> 计划 -> 审核 -> 执行 -> Azure

持续集成：代码 -> 编译 -> 测试 -> 扫描 -> 镜像 -> 制品证据

持续交付：制品 -> DEV -> TEST -> PROD -> 验证 / 回滚
```

---

## 2. 重要名词先解释

第一次看项目时先记住下面这些词，后面的 README 会反复使用。

| 名词 | 中文解释 | 人话说明 |
|---|---|---|
| IaC | Infrastructure as Code，基础设施即代码 | Azure 网络、AKS、存储、数据库等不靠人手点控制台，而是通过代码和审批创建 |
| CI | Continuous Integration，持续集成 | 代码提交后自动编译、测试、扫描、制作镜像 |
| CD | Continuous Delivery/Deployment，持续交付/部署 | 已经构建好的制品如何安全进入 DEV、TEST、PROD |
| GitOps | 基于 Git 的期望状态发布模式 | Kubernetes 不让 CI 直接改，先改 Git，Flux 再让集群跟 Git 保持一致 |
| AKS | Azure Kubernetes Service | Azure 托管 Kubernetes 集群 |
| ACR | Azure Container Registry | Azure 容器镜像仓库，保存构建镜像和应用镜像 |
| OIDC | OpenID Connect | GitHub Actions 临时向 Azure 证明“我是谁”，不用长期保存 Client Secret |
| WIF | Workload Identity Federation，工作负载联合身份 | Azure 侧对 OIDC 的联合身份机制，核心也是取消长期密钥 |
| UAMI | User Assigned Managed Identity，用户分配托管身份 | Azure 中独立存在、可单独授权的身份 |
| RBAC | Role Based Access Control，基于角色的权限控制 | 谁能读、谁能写、能操作到什么范围 |
| PR | Pull Request，合并请求 | 所有重要变更先提交审核，再合并 |
| Terraform Plan | Terraform 变更计划 | 先告诉你“准备创建/修改/删除什么”，不真正执行 |
| Terraform Apply | Terraform 执行 | 真正把已经审核的计划应用到 Azure |
| State | Terraform 状态文件 | Terraform 用来记住“哪些云资源归我管理、现在是什么状态” |
| Matrix | 矩阵并行任务 | 同一套流程同时跑 Java、Python、Go、C++ 或多个模块 |
| needs | GitHub Actions 任务依赖关系 | 明确某个 Job 必须等哪个 Job 成功后才能继续 |
| Reusable Workflow | 可复用工作流 | 平台维护一份标准 CI，各项目调用，不允许每个项目复制魔改 |
| DAG | 有向无环依赖图 | 人话：把流水线任务依赖画成一张不会循环的执行图 |
| Digest | 镜像内容摘要，通常是 sha256 | 镜像真正的唯一身份证，比 `v1`、`latest` 标签可靠 |
| SBOM | Software Bill of Materials，软件物料清单 | 记录镜像里到底用了哪些软件包和版本 |
| Provenance | 构建来源证明 | 记录这个制品是由什么源码、什么构建环境生成的 |
| Flux | GitOps 控制器 | 持续观察 Git，一旦目标环境状态变化，就同步到 Kubernetes |
| Kustomize | Kubernetes YAML 组合工具 | 用基础模板加环境差异生成最终 DEV/TEST/PROD 配置 |

---

## 3. 当前项目真实状态

```text
仓库：iwacollection/k3s-gitops
平台开发分支：design/azure-enterprise-control-plane-v1
平台 PR：#5，当前仍保持 Draft
稳定主分支：main

DEV 期望状态分支： gitops/dev
TEST 期望状态分支：gitops/test
PROD 期望状态分支：gitops/prod
```

当前不是只有目录框架。

### DEV 已经真实跑通

真实 Azure DEV 全链路已经验证成功：

```text
GitHub OIDC 登录 Azure
    -> ACR 标准构建镜像
    -> 应用持续集成
    -> 生成不可变应用镜像摘要
    -> 发布申请
    -> GitOps 发布 PR
    -> 合并 gitops/dev
    -> Flux 同步
    -> AKS Deployment Ready
    -> Endpoint Ready
    -> 精确镜像摘要验证通过
```

详细 DEV 证据：

```text
enterprise-cicd/activation/DEV-ACTIVATION-EVIDENCE.md
```

### TEST 已完成真实只读盘点，正在激活

TEST 当前不是再建一套昂贵 AKS，而是在当前实验环境中复用物理 AKS，同时保持独立逻辑边界。

真实盘点确认：

```text
已有 AKS：             group-test / k8s-test-cicd
已有 ACR：             acrcicdc12c3a3699d8
TEST Git 分支：        gitops/test 已存在
TEST Namespace 清单： cicd-test 已存在于 Git
DEV 已批准镜像摘要：  在 ACR 中仍然存在
```

当前 TEST 只剩两个 Azure 运行态阻塞：

```text
missing-test-github-oidc-binding
missing-test-flux-configuration
```

对应人话：

```text
1. TEST 还没有自己独立的 GitHub -> Azure 身份。
2. TEST 还没有自己独立的 Flux 同步配置。
```

TEST 激活计划：

```text
enterprise-cicd/activation/test/TEST-ACTIVATION-PLAN.md
```

### PROD 仍保持受控阻断

PROD 还没有激活。

特别是 PostgreSQL Flexible Server 的生产环境仍要求提供真实的 Microsoft Entra DBA Group Object ID 和 Principal Name，在这两个生产身份信息没有明确之前，不允许平台假装已经可以生产部署。

---

## 4. 为什么企业级平台不能让每个研发自己写流水线

如果每个项目自己维护：

```text
自己的 Terraform
自己的 GitHub Actions
自己的 Maven/Python/Go/C++ 环境
自己的 Dockerfile 规则
自己的安全扫描
自己的 Kubernetes 发布脚本
自己的 Azure 权限
```

很快会出现：

```text
项目 A 用 Java 17
项目 B 用 Java 21
项目 C 私自关闭漏洞扫描
项目 D 用 latest 镜像
项目 E CI 直接拿 cluster-admin
项目 F Terraform State 放本地
项目 G 修改生产没有审批
项目 H 缓存和源码混在一起导致构建污染
```

所以本平台采用：

```text
平台拥有实现
研发提交意图
```

也就是：

```text
研发负责：
- 我要什么资源
- 我的应用是什么语言
- 代码在哪里
- 我要发布哪个制品
- 我要去哪个环境

平台负责：
- Terraform Module
- 资源命名
- 网络边界
- 身份权限
- CI 模板
- 构建镜像
- 安全扫描
- 发布策略
- 审批
- GitOps
- 回滚和验证
```

---

## 5. 平台整体架构

```text
                        ┌─────────────────────────┐
                        │        研发人员          │
                        └────────────┬────────────┘
                                     │
          ┌──────────────────────────┼──────────────────────────┐
          │                          │                          │
          ▼                          ▼                          ▼
   基础设施申请                 应用代码提交                 发布申请
          │                          │                          │
          ▼                          ▼                          ▼
  IaC 服务目录                GitHub Actions              发布策略检查
  + 参数规则                  标准持续集成                      │
  + 环境绑定                       │                          ▼
          │                          ▼                    GitOps 发布 PR
          ▼                    标准构建镜像                      │
 Azure DevOps                       │                          ▼
 Terraform Plan                     ▼                    gitops/dev|test|prod
          │                    编译/测试/扫描                    │
          ▼                          │                          ▼
        审核                         ▼                        Flux
          │                       ACR 制品                       │
          ▼                                                     ▼
 Saved Plan Apply                                              AKS
          │                                                     │
          ▼                                                     ▼
        Azure                                                只读验证
```

三个主要控制面保持分工：

```text
GitHub Actions
    -> 负责应用 CI、制品生产、发布申请和验证流程

Azure DevOps
    -> 负责 Terraform 基础设施治理、环境审批和受控 Apply

Flux
    -> Kubernetes 工作负载真正的写入和持续同步者
```

最关键的边界：

**GitHub Actions 的应用 CI 不直接执行生产 `kubectl apply`，也不直接使用 Helm 去修改生产工作负载。**

---

## 6. 基础设施即代码（IaC）怎么管理

### 6.1 研发不是直接写 Azure Provider Resource

普通研发默认不直接提交大量：

```hcl
resource "azurerm_xxx" "xxx" {
  ...
}
```

而是提交标准化基础设施申请。

目录结构：

```text
iac-catalog/services/<服务类型>/<版本>/
├── catalog.json
├── request.schema.json
├── defaults.json
├── policy.json
└── request.example.json
```

含义：

```text
catalog.json
    -> 这个基础设施产品叫什么、当前版本是什么

request.schema.json
    -> 研发允许填写哪些字段，字段类型和必填项是什么

defaults.json
    -> 平台默认值

policy.json
    -> DEV/TEST/PROD 分别允许什么，不允许什么

request.example.json
    -> 研发参考模板
```

所以真实使用模式是：

```text
研发填需求变量
    -> Schema 校验
    -> 平台默认值
    -> 环境策略
    -> 命名规则
    -> 网络绑定
    -> 身份绑定
    -> 编译成 Terraform 输入
```

这就是我们前面确定的企业模式：**Terraform 应该有标准模板，研发只提交需求变量，审核后才创建资源。**

### 6.2 当前基础设施服务目录

| 服务目录 | 中文用途 | 当前主要约束 |
|---|---|---|
| `acr/v1` | Azure 容器镜像仓库 | SKU 和镜像仓库基线受平台控制 |
| `storage/v1` | Azure 存储账户 | 禁止 Shared Key、私网接入、诊断、生产资源锁 |
| `managed-identity/v1` | 托管身份 | 工作负载身份和权限边界 |
| `key-vault/v1` | 密钥与证书管理 | 关闭公网、私有终结点、私有 DNS、删除保护、诊断 |
| `service-bus/v1` | Azure 消息总线 | Premium 私网模式、本地认证关闭、诊断 |
| `managed-redis/v1` | Azure 托管 Redis | 关闭 Access Key、私有终结点、私有 DNS、诊断 |
| `postgresql-flexible/v1` | PostgreSQL Flexible Server | VNet 委派、私有 DNS、Entra 身份；PROD 需真实 DBA Group |

### 6.3 环境公共资源不能让研发手填 Resource ID

研发不应该自己复制这些 Azure Resource ID：

```text
VNet ID
Subnet ID
Private DNS Zone ID
AKS ID
ACR ID
Identity ID
```

平台统一从下面的环境绑定文件解析：

```text
enterprise-cicd/contracts/environment-bindings.json
```

这避免每个项目把 DEV 的 Subnet ID 复制到 PROD 之类的事故。

---

## 7. Terraform Plan / Apply / State 怎么治理

### 7.1 先计划，后执行

Terraform 的核心发布原则：

```text
PR
 -> Terraform Plan
 -> 人工/策略审核
 -> Merge
 -> 再次 Plan
 -> 生成精确 Saved Plan
 -> 受控 Apply
```

不能：

```text
PR 一提交
 -> terraform apply
 -> Azure 已经被改了
```

### 7.2 为什么合并后还要重新 Plan

因为 PR 审核期间真实 Azure 状态可能已经变化。

所以企业级流程不能拿几小时前生成的计划直接执行，应该在最终执行前重新确认。

### 7.3 Saved Plan

Saved Plan 是 Terraform 保存下来的精确执行计划。

人话：

```text
审核的是 A
最终执行的也必须是 A
不能审核 A，执行时又重新算出 B
```

### 7.4 Terraform State 隔离

Catalog Request 使用独立 State：

```text
catalog/{environment}/{service}/{request}.tfstate
```

原则：

```text
一个请求 / 一组合理资源
    -> 一个独立 State
    -> 一个独立 Lock
```

这样可以减少 Blast Radius（故障影响范围）。

假设某个 Redis 申请的 State 出现问题，不应该把整个企业所有 AKS、数据库、存储一起锁死。

### 7.5 环境身份隔离

```text
DEV
  tf-plan-dev
  tf-apply-dev

TEST
  tf-plan-test
  tf-apply-test

PROD
  tf-plan-prod
  tf-apply-prod
```

不允许：

```text
一个 Contributor 身份
 -> DEV
 -> TEST
 -> PROD
 -> 所有 Azure 资源
```

---

## 8. Azure DevOps 在这里负责什么

Azure DevOps 主要承担 **基础设施和环境治理**，而不是替代 GitHub Actions 做所有事情。

当前设计包括：

```text
基础设施申请发现
 -> PR Terraform Plan
 -> 计划证据
 -> Merge 后重新 Plan
 -> 精确 Saved Plan Apply
```

企业治理能力：

```text
固定 DEV / TEST / PROD Service Connection
WIF/OIDC 无长期密钥认证
Environment 审批
Branch Control 分支控制
Required Template 强制模板
Exclusive Lock 独占锁
```

### Service Connection 是什么

Service Connection 可以理解为：

**Azure DevOps 访问 Azure 时使用的受控身份入口。**

本平台不允许通过运行时字符串随意拼接 Service Connection 名称，因为那会绕过 Azure DevOps 的静态权限和审批检查。

---

## 9. Terraform 基础设施能力

Terraform 当前已经建立标准 Module 和 Root Stack。

### 网络基础

```text
VNet                       Azure 虚拟网络
Subnet                     子网
NSG                        网络安全组
Route Table / UDR          自定义路由
NAT Gateway                出公网网关
Private DNS                私有 DNS
VNet Link                  DNS 与 VNet 关联
Private Endpoint           私有终结点
DNS Zone Group             私有终结点 DNS 绑定
RBAC Role Assignment       权限绑定
```

标准网络槽位：

```text
snet-aks
snet-private-endpoints
snet-postgresql
```

### AKS 标准能力

标准 AKS Module / Root Stack 包含：

```text
Standard Tier
可选私有集群
关闭 Local Account
Azure RBAC
OIDC Issuer
Workload Identity
Azure Policy
Azure CNI
Standard Load Balancer
Key Vault CSI + 自动轮换
System Node Pool 自动扩缩容
Kubelet Identity 拉取 ACR
Container Insights
Managed Prometheus
```

当前实验环境真实 AKS：

```text
Resource Group: group-test
AKS:            k8s-test-cicd
DEV Namespace:  cicd-dev
```

标准 Terraform AKS Module 不会偷偷替换现有实验集群。

### 可观测性

平台已经包含：

```text
Log Analytics Workspace
Azure Monitor Workspace
Container Insights
Managed Prometheus
Diagnostic Settings
```

其中：

```text
DCR   = Data Collection Rule，数据采集规则
DCRA  = Data Collection Rule Association，采集规则绑定
DCE   = Data Collection Endpoint，数据采集入口
```

Managed Grafana 当前属于 V1 之后可选增强能力。

---

## 10. 持续集成（CI）怎么管理

### 10.1 CI 的核心不是每个项目写 YAML

我们采用：

```text
Application Definition
    -> Build Profile
    -> Reusable Workflow
    -> 标准 Build Image
```

也就是：

```text
研发描述“这个应用是什么”
平台决定“这个类型的应用应该怎么安全构建”
```

### 10.2 Application Definition

Application Definition 是应用定义。

人话：告诉平台：

```text
应用名是什么
代码目录在哪里
是什么语言
使用哪个标准构建规格
最后要构建什么镜像
```

它支持 `sourcePath`，所以一个仓库里可以存在多个服务，不要求业务代码全部放仓库根目录。

这对 Monorepo（单仓库多项目）非常重要。

### 10.3 Build Profile

Build Profile 是标准构建规格。

当前支持：

| 语言 | 标准构建规格 | 平台构建镜像 |
|---|---|---|
| Java | `java/springboot-maven-v1` | `java21-maven:v1` |
| Python | `python/python-uv-v1` | `python-uv:v1` |
| Go | `go/go-service-v1` | `go-builder:v1` |
| C++ | `cpp/cmake-conan-v1` | `cpp-cmake-conan:v1` |

以后研发不应该在每个项目里自己装一遍 Maven、uv、Go、CMake、Conan。

### 10.4 Reusable Workflow、Matrix、needs 的关系

这三个是当前 CI 设计的重要组成部分。

#### Reusable Workflow：统一模板

例如平台维护：

```text
标准 Java CI
标准 Python CI
标准 Go CI
标准 C++ CI
```

业务仓库调用它，而不是复制源码。

#### Matrix：并行展开

例如：

```text
Matrix
├── Java
├── Python
├── Go
└── C++
```

或者：

```text
Matrix
├── service-a
├── service-b
├── service-c
└── service-d
```

可以同时运行。

#### needs：任务依赖

例如：

```text
resolve
   ├── source-scan
   └── build-test
          |
          v
      image-build
          |
     ┌────┴─────┐
     v          v
 image-scan    SBOM
     └────┬─────┘
          v
         sign
          |
          v
 release-evidence
```

这里 `needs` 就是在表达谁必须等谁。

这三者组合起来就是：

```text
Reusable Workflow = 标准化
Matrix            = 并行化
needs             = 依赖编排
```

---

## 11. 标准构建镜像为什么重要

当前四套构建镜像已经真实发布到：

```text
acrcicdc12c3a3699d8.azurecr.io
```

对应真实摘要：

| 构建镜像 | sha256 摘要 |
|---|---|
| `build/java21-maven:v1` | `sha256:02ea4848f16f7d70811bcd1c66b78354648510341d835ab06154eb3052dcbaf6` |
| `build/python-uv:v1` | `sha256:f6d63e38fbb3bd2e1edae918afbc1e3abafdb0f4dc961449d33f5c2d8722c02d` |
| `build/go-builder:v1` | `sha256:813d1bcbe71bb2bdaebcb622c4af65d5a02ee6196e98c0aed3535109f51f5ace` |
| `build/cpp-cmake-conan:v1` | `sha256:8864bafcd66839cc76577f450c4988b0d06d4e3be6bcf3ba6b29c332faf6fb6e` |

运行 CI 时不只相信：

```text
java21-maven:v1
```

而是解析成：

```text
java21-maven@sha256:xxxxxxxx
```

原因很简单：

```text
Tag 可以被重新指向
Digest 对应具体内容
```

所以 sha256 才是企业制品真正的身份证。

---

## 12. 依赖缓存怎么避免并发污染

多个项目同时构建时，如果大家乱用同一个缓存目录，会出现：

```text
并发写缓存
缓存锁竞争
缓存文件半写入
版本污染
不同项目互相覆盖
源码目录混入依赖
Docker Build Context 被意外放大
```

当前设计把源码与缓存物理隔离：

```text
源码：
/workspace

缓存：
$RUNNER_TEMP/platform-cache/<application>/<profile>

Docker 构建上下文：
单独隔离
```

所以 Maven、Python、Go、Conan 的缓存不是直接乱写业务源码目录。

后续接企业 Nexus、Artifactory、私有 PyPI、Maven Repository、Go Proxy、Conan Repository 时，也应该继续维持：

```text
远端依赖代理
    +
Runner 本地缓存
    +
项目级隔离
```

而不是所有项目共同写一个无隔离目录。

---

## 13. 应用 CI 的完整安全链路

当前 Application CI v2 的逻辑：

```text
解析应用定义
    -> 源码安全扫描
    -> 编译 + 单元测试
    -> 构建应用镜像
    -> 镜像漏洞扫描
    -> 生成 SBOM
    -> 生成构建来源证明
    -> Cosign OIDC 签名
    -> 生成 Release Evidence
```

### SBOM

SBOM 是软件物料清单。

人话：

```text
这个镜像里面到底装了什么包？
用了什么版本？
后面爆出 Log4j 之类漏洞时能不能快速定位？
```

### Provenance

Provenance 是构建来源证据。

人话：

```text
这个镜像到底是不是我们的 CI
从这次源码提交
在规定的构建环境里生成的？
```

### Cosign

Cosign 用于给容器制品签名。

当前使用 GitHub OIDC 的无长期私钥方式完成签名。

### 真实安全 Gate 已经发生过拦截

真实 smoke CI 中曾经因为 Debian Runtime Image 存在**可修复 HIGH 漏洞**而被平台阻断。

正确处理方式是：

```text
发现漏洞
 -> 修复/升级基础镜像依赖
 -> 重新扫描
 -> 通过
```

而不是：

```text
扫描红了
 -> 把 HIGH / CRITICAL 改成 warning
 -> 强行上线
```

---

## 14. Build Once，Promote Same Digest

这是整个 CD 的核心规则。

中文可以理解成：

**只构建一次，后续环境只晋级同一个制品。**

例如 DEV 已验证：

```text
platform-smoke-api
@sha256:b0faf7a8f90618cd7a6b081085d3af3ca666afa015aac9827f71cf198816e2ba
```

进入 TEST 时不能重新 Build 一个：

```text
:test
```

进入 PROD 时也不能再 Build 一个：

```text
:prod
```

正确逻辑：

```text
同一个 sha256
    -> DEV 验证
    -> TEST 验证
    -> PROD 发布
```

为什么？

因为如果三个环境分别重新 Build：

```text
DEV 验证的是 A
TEST 重新构建成 B
PROD 又重新构建成 C
```

那 DEV/TEST 的验证并不能证明 PROD 的 C 是安全的。

---

## 15. 持续交付（CD）与 GitOps

应用发布链路：

```text
已构建制品
 -> Release Request 发布申请
 -> 发布策略校验
 -> 读取目标环境 Git 基线
 -> 生成目标环境变更
 -> 创建受保护 GitOps PR
 -> 审核并合并
 -> Flux 发现 Git 变化
 -> Flux 修改 AKS
 -> 只读验证
```

允许的环境晋级关系只有：

```text
build -> dev -> test -> prod
```

不应该：

```text
开发分支 -> 直接 PROD
DEV 制品 -> 跳过 TEST -> PROD
PROD 临时手工重新 Build
```

---

## 16. 为什么 CI 不能直接 kubectl apply

这是企业 CI/CD 和普通 Demo 最大区别之一。

如果 GitHub Actions CI 本身拥有 Kubernetes 写权限：

```text
CI Token 泄露
   -> 可以直接改 Deployment
   -> 可以删 Service
   -> 可以改 ConfigMap / Secret
   -> 可以绕过 Git 审核
```

而当前设计是：

```text
CI
 -> 只能生成制品 / Release Request / Git 变更

Flux
 -> 才是 Kubernetes 写入者
```

这样 Kubernetes 的变化一定能追溯到 Git。

这就是 GitOps 的核心治理价值。

---

## 17. DEV / TEST / PROD 的 Git 状态怎么隔离

每个环境都有独立的期望状态分支：

```text
gitops/dev
gitops/test
gitops/prod
```

所谓“期望状态”就是：

**Git 里写着这个环境应该运行什么。**

例如：

```text
gitops/dev
    -> DEV 应该运行 digest A

gitops/test
    -> TEST 应该运行 digest A

gitops/prod
    -> PROD 应该运行 digest A
```

发布时必须从**目标环境自己的 Git 分支**作为基线创建变更。

不能从平台开发分支直接往 `gitops/dev` 塞所有代码，否则很容易把不属于运行环境的文件一起带进去。

---

## 18. Flux 在这里负责什么

Flux 是 Kubernetes GitOps 控制器。

它做的是：

```text
不断检查 Git
    -> 发现目标分支有变化
    -> 读取 Kustomize 配置
    -> 和 AKS 当前状态比较
    -> 自动把 AKS 调整成 Git 声明的状态
```

所以：

```text
Git = 期望状态
AKS = 实际状态
Flux = 让实际状态追上期望状态
```

DEV 当前真实 Flux：

```text
配置名：enterprise-cicd
Flux Namespace：enterprise-cicd
Git 分支：gitops/dev
```

TEST 目标 Flux：

```text
配置名：enterprise-cicd-test
Flux Namespace：enterprise-cicd-test
Git 分支：gitops/test
Kustomization：apps-test
```

TEST 不重复接管共享基础设施目录，避免 DEV Flux 和 TEST Flux 同时拥有同一份 Kubernetes 基础设施资源。

---

## 19. 身份和权限模型

### 19.1 不保存长期 Azure Client Secret

GitHub Actions 使用：

```text
GitHub OIDC Token
    -> Azure Federated Credential
    -> UAMI
    -> RBAC
```

人话：

GitHub 每次任务临时证明自己身份，Azure 根据预先建立的信任关系给它临时访问能力。

避免：

```text
AZURE_CLIENT_SECRET=xxxxxxxx
```

长期放在仓库 Secret 里。

### 19.2 DEV 和 TEST 不能共用一个身份

即使实验环境 DEV/TEST 共用同一套物理 AKS，也不能共用同一个 Principal。

否则：

```text
DEV 身份
 + cicd-dev 权限
 + cicd-test 权限
```

逻辑环境隔离就被打穿了。

所以 TEST 使用独立：

```text
UAMI：k3s-gitops-test-uami
OIDC Subject：repo:iwacollection/k3s-gitops:environment:test
```

### 19.3 TEST 最小权限目标

```text
Reader
 -> 仅 AKS Resource Scope

Azure Kubernetes Service Cluster User Role
 -> 仅 AKS
 -> 只用于获取非管理员 kubeconfig

Azure Kubernetes Service RBAC Reader
 -> 仅 cicd-test namespace

AcrPull
 -> 仅 ACR
```

明确禁止：

```text
Owner
Contributor
User Access Administrator
Azure Kubernetes Service RBAC Writer
Azure Kubernetes Service RBAC Admin
AcrPush
```

而且 TEST Observer 会主动验证：

```text
get Deployment    = yes
get EndpointSlice = yes
create Deployment = no
patch Deployment  = no
delete Deployment = no
```

也就是说，验证身份本身没有发布写权限。

---

## 20. 实验环境与真正生产环境的区别

当前 Azure 实验环境为了控制费用，合同明确采用：

```text
物理创建环境：DEV
逻辑环境：TEST / PROD
```

所以当前实验验证会复用：

```text
同一个 AKS
同一个 ACR
```

但仍然分离：

```text
GitHub Environment
OIDC/UAMI Principal
Namespace
GitOps Branch
Flux Configuration
权限 Scope
```

这只是**实验环境物理边界压缩**。

真正生产目标仍应该按风险拆分：

```text
DEV / TEST
    -> 非生产边界

PROD
    -> 独立生产 Subscription / Resource Group / Identity / Approval / Lock
```

不能因为 Lab 共用 AKS，就理解成真正企业生产也应该把所有环境塞一套集群里。

---

## 21. 真实 DEV E2E 证据

验证应用：

```text
platform-smoke-api
```

最终通过所有 CI Gate 的应用制品：

```text
acrcicdc12c3a3699d8.azurecr.io/apps/platform-smoke-api
@sha256:b0faf7a8f90618cd7a6b081085d3af3ca666afa015aac9827f71cf198816e2ba
```

真实 CI 结果：

```text
应用解析              PASS
源码扫描              PASS
编译与测试            PASS
镜像构建              PASS
镜像扫描              PASS
SBOM                  PASS
Cosign 签名           PASS
发布证据              PASS
```

真实 DEV Release Request：

```text
enterprise-cicd/release-requests/platform-smoke-api-to-dev.json
```

Promotion PR #6：

```text
目标分支：gitops/dev
Commit：1
变更文件：3
GitOps Platform Validate：PASS
CD Closure Validate：PASS
Framework Structure Validate：PASS
```

合并 Commit：

```text
37ae91eed8e2c40038524d1b524111056dc637ce
```

最终 AKS 验证：

```text
Flux 合规：           true
Deployment：          platform-smoke-api
Namespace：           cicd-dev
期望副本：            1
Available 副本：      1
Ready 副本：          1
EndpointSlices：      1
Ready Endpoint：      1
精确 Digest：         PASS
最终验证：            passed
```

---

## 22. TEST 当前激活流程

### Phase 0：GitHub TEST Environment

必须先存在：

```text
GitHub Environment: test
```

当前 Draft 阶段允许受控：

```text
design/azure-enterprise-control-plane-v1
main
```

不能依赖 GitHub 自动创建一个没有保护规则的 `test` Environment。

### Phase A：独立 TEST Azure 身份

脚本：

```text
enterprise-cicd/activation/test/bootstrap-test-identity.sh
```

默认只是 Plan Only。

只有显式：

```bash
--apply
```

才会写 Azure。

执行后生成：

```text
test-identity-activation-result.json
```

里面保存非敏感身份信息：

```text
clientId
principalId
tenantId
subscriptionId
resourceId
federatedSubject
roleAssignments
```

然后把真实 ID 回填：

```text
enterprise-cicd/contracts/environment-bindings.json
```

之后 TEST Readiness 会真正使用 `environment:test` 登录 Azure，而不是只看 JSON 里有没有字段。

### Gate A：真实身份验证

必须证明：

```text
TEST OIDC 真能登录
TEST Principal != DEV Principal
TEST 能读取 cicd-test
TEST 不能创建/修改/删除 Deployment
TEST 能读取批准的 ACR Digest
```

### Phase B：TEST Flux

脚本：

```text
enterprise-cicd/gitops/clusters/aks-automatic-lab-test/bootstrap-flux-aks-test.sh
```

目标：

```text
Flux Config： enterprise-cicd-test
Namespace：   enterprise-cicd-test
Branch：      gitops/test
Kustomization：apps-test
Path：        ./enterprise-cicd/gitops/environments/test
```

### Gate B

最终 TEST Readiness 必须达到：

```text
status = ready
blockers = []
```

之后才允许真正执行：

```text
DEV
 -> TEST
 -> 同一个 b0faf7... sha256
```

---

## 23. 研发人员日常怎么使用

研发真正需要记的入口不应该很多。

### 23.1 申请基础设施

```text
选择平台已有服务模板
 -> 填 Infrastructure Request
 -> 提交 PR
 -> 自动规则校验
 -> Terraform Plan
 -> 平台/SRE 审核
 -> 合并
 -> 受控 Apply
```

研发不需要：

```text
自己创建 VNet
自己填一长串 Azure Resource ID
自己管理 Terraform Backend
自己持有生产 Contributor
```

### 23.2 提交应用代码

```text
代码提交
 -> Application Definition
 -> 平台 Build Profile
 -> Reusable CI
 -> 标准 Build Image
 -> 编译 / 测试 / 扫描
 -> ACR Immutable Digest
```

研发主要负责：

```text
业务代码
单元测试
应用自己的构建声明
必要的 sourcePath / 应用信息
```

### 23.3 发布应用

```text
选择已经通过 CI 的 Digest
 -> Release Request
 -> 目标环境
 -> GitOps PR
 -> 审核
 -> Flux
 -> 验证
```

研发不能自己重新 Build 一个 PROD 镜像绕过已验证制品。

---

## 24. 平台 / SRE 团队日常怎么使用

平台团队主要维护：

```text
Terraform Module
IaC Catalog
Environment Binding
Policy
Build Profile
Build Image
Reusable Workflow
OIDC / UAMI / RBAC
GitOps Contract
Release Profile
Flux
验证和回滚能力
```

平台团队不是每次替研发手工点 Azure，而是持续维护**标准能力和安全边界**。

当新需求出现，例如研发要 Azure Service Bus：

```text
不是：
SRE 每次手工创建一个 Service Bus

而是：
SRE 维护 service-bus/v1 标准产品
 -> 研发以后反复提交 Request
 -> 自动执行同一套治理规则
```

这就是平台工程的核心价值。

---

## 25. 生产发布应该由谁审批

PROD 不应该只因为 CI 绿了就自动获得写权限。

完整生产模型应该是：

```text
TEST 验证证据
 -> PROD Release Request
 -> Branch / Policy Check
 -> Environment Approval
 -> Exclusive Lock
 -> GitOps PR
 -> 审核
 -> Flux 发布
 -> 健康验证
```

高风险基础设施变更也一样：

```text
Terraform Plan
 -> 审核
 -> PROD Environment Approval
 -> Exclusive Lock
 -> Saved Plan Apply
```

---

## 26. 回滚模型

回滚也必须遵守不可变制品原则。

正确方式：

```text
当前 PROD Digest B 出现问题
    -> 找到 previous-approved-digest A
    -> 创建回滚 Release Request
    -> GitOps PR
    -> Flux 恢复 A
    -> 验证
```

不能：

```text
临时进服务器改文件
kubectl edit
重新 Build 一个“差不多”的旧版本
```

后续阶段还会专门执行 rollback / failed-health drill，验证这条链路。

---

## 27. Terraform 工程目录

```text
terraform/
├── bootstrap/                    # Terraform 平台自身初始化
├── state/                        # State 相关定义
├── modules/                      # 平台维护的可复用资源模块
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
└── stacks/                       # 可实际部署的 Root Stack
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

### Module 和 Root Stack 的区别

```text
Module
 -> 通用零件
 -> 定义“一个标准 AKS 应该怎么建”

Root Stack
 -> 实际装配入口
 -> 定义“这个环境具体使用哪些 Module 和变量”
```

---

## 28. enterprise-cicd 主要目录怎么理解

下面不是完整文件树，而是按职责理解最重要的目录：

```text
enterprise-cicd/
├── activation/                   # DEV/TEST/PROD 激活、盘点和验证证据
├── application-definitions/      # 应用是什么、代码在哪里、使用什么 Build Profile
├── architecture/                 # 架构设计说明
├── artifacts/                    # 平台制品相关定义/证据
├── azure-devops/                 # Azure DevOps 治理模型
├── azure-pipelines/              # Azure Pipelines 模板/流程
├── build-images/                 # Java/Python/Go/C++ 标准构建镜像
├── ci-catalog/                   # CI 标准能力目录
├── ci-scripts/                   # CI 公共脚本
├── contracts/                    # 环境、身份、State、Pipeline 等平台合同
├── dependency-proxy/             # 依赖代理相关设计
├── gitops/                       # Kubernetes 期望状态和 Flux 配置
├── iac-catalog/                  # 研发可申请的 IaC 服务目录
├── promotion/                    # 环境晋级逻辑
├── release-catalog/              # Rolling/Canary/Blue-Green 发布策略目录
├── release-requests/             # 实际发布申请
├── testing/                      # 平台自身 Contract / Framework 验证
└── terraform/                    # Terraform Module 和 Root Stack
```

如果只是使用平台，研发通常不需要理解所有目录。

---

## 29. 发布策略目录

当前 Release Catalog 包含：

```text
Rolling
Canary
Blue-Green
```

### Rolling

滚动发布，当前 V1 已具备执行能力。

人话：逐步替换旧 Pod，不一次性全停。

### Canary

金丝雀发布。

人话：先让少量流量去新版本，观察没问题再扩大。

当前策略可以描述，但没有真实渐进式发布控制器前保持 execution blocked，不假装已经生产可用。

### Blue-Green

蓝绿发布。

人话：同时准备老环境和新环境，最后切流量。

同样，在真实流量切换控制器完成前不标记为可执行。

---

## 30. 平台自动验证

平台自己也必须被 CI 检查，不能只有业务应用被检查。

当前主要验证包括：

```text
Control Contract Validate
    -> 平台核心合同是否被破坏

Framework Structure Validate
    -> 目录和框架结构是否完整

Terraform Framework Validate
    -> Terraform 是否能初始化并通过 validate

Platform Catalog Validate
    -> IaC / CI Catalog 是否符合规范

Build Platform Validate
    -> 构建平台逻辑是否正确

Build Profile Smoke
    -> 标准构建规格能否实际运行

GitOps Platform Validate
    -> GitOps 不可变制品、分支、Flux、TEST 权限模型是否符合规则

Azure DevOps Platform Validate
    -> Azure DevOps 治理模型是否符合约束

CD Closure Validate
    -> CD 闭环是否完整

Platform Activation Readiness
    -> 平台是否具备激活条件

Azure DEV Activation Preflight
    -> DEV Azure 前置条件

Azure TEST Readiness Inventory
    -> TEST 真实只读盘点 + OIDC/RBAC Gate

Platform Build Images Verify
    -> 标准构建镜像真实性和 Digest

Platform Smoke Application CI
    -> 真实应用 CI 全链路

Platform Smoke DEV Observe
    -> DEV 部署后的只读验证

Platform Smoke TEST Observe
    -> TEST 激活后验证同 Digest 和只读权限
```

Terraform 当前使用 **12 个 Root Stack Matrix 并行验证**：

```text
terraform init -backend=false
terraform validate
```

Validation Workflow 明确禁止执行：

```text
terraform apply
```

也就是说“检查代码”不会顺便修改 Azure。

---

## 31. 这套平台明确禁止什么

### 基础设施

禁止：

```text
研发随意直接 terraform apply PROD
本地 State 管生产
一个 Contributor 管所有环境
PR 校验阶段直接 Apply
运行时动态选择高权限 Service Connection
```

### CI

禁止：

```text
每个项目复制一份企业模板后随便改
使用 latest 作为最终可追溯制品
关闭安全 Gate 只为让流水线变绿
多个项目无隔离共享可写缓存
把缓存目录混入源码和 Docker Build Context
```

### CD / Kubernetes

禁止：

```text
应用 CI 直接 kubectl apply
应用 CI 直接 helm upgrade 生产应用
DEV/TEST/PROD 重新 Build 三次
DEV 和 TEST 共用同一个高权限 Principal
绕过 GitOps 手工长期修改 Deployment
```

---

## 32. 发生故障时怎么理解这套链路

### CI 红了

先判断是哪一层：

```text
源码扫描
编译
单元测试
依赖缓存
镜像构建
镜像漏洞
SBOM
签名
ACR 推送
```

不要看到 CI 红了就直接关闭安全检查。

### Terraform Plan 异常

```text
现象
 -> Plan 出现大量意外删除/重建

判断
 -> 检查 State、Provider、环境 Binding、Module 变更

证据
 -> Saved Plan / State / Azure 实际资源

事故处理
 -> 禁止 Apply

恢复验证
 -> 修复输入后重新 Plan

长期治理
 -> Contract / Policy / Module 增加防护
```

### Flux 不同步

```text
现象
 -> Git 已合并，AKS 没变化

判断
 -> Flux Source / Kustomization / Compliance / Git Commit

证据
 -> Flux Status、sourceSyncedCommitId、Kustomization Ready

事故处理
 -> 不要先手工 kubectl apply 绕过 GitOps

恢复验证
 -> Flux 恢复 Compliant，目标 Commit 已同步

长期治理
 -> Readiness / Observation 增加对应 Gate
```

### 发布后 Pod 不 Ready

```text
现象
 -> Deployment 已更新，Ready 副本不足

判断
 -> 镜像、Probe、Config、Secret、资源、下游依赖

证据
 -> Deployment / Pod Events / Logs / Metrics

事故处理
 -> 停止继续晋级，必要时回滚 previous-approved-digest

恢复验证
 -> 副本数、Endpoint、业务探测恢复

长期治理
 -> 增加 CI/CD 健康 Gate 和发布策略
```

---

## 33. 当前下一阶段

当前优先级已经不是继续无止境新增 DEV Module。

接下来按顺序：

```text
1. 完成 GitHub test Environment 信任边界

2. 激活 TEST 独立 UAMI / OIDC / 最小 RBAC

3. TEST Readiness 真正验证 environment:test 身份

4. 创建独立 enterprise-cicd-test Flux Configuration

5. TEST Readiness 达到 ready

6. 使用 DEV 已批准的同一个
   sha256:b0faf7...
   执行 DEV -> TEST

7. Platform Smoke TEST Observe 验证
   - Flux
   - exact digest
   - replicas
   - endpoints
   - TEST 身份无 Kubernetes 写权限

8. 补真实 PostgreSQL PROD Entra DBA Group

9. 激活 PROD Identity / Approval / Environment Protection

10. 同一个 Digest 执行 TEST -> PROD

11. 执行回滚和失败健康检查演练

12. V1 之后再考虑 Managed Grafana、真实 Canary/Blue-Green Controller
```

PR #5 在平台整体评审完成前继续保持 Draft，不自动合并到 `main`。

---

## 34. 最后用一张图记住整个项目

```text
                        企业研发
                           |
          +----------------+----------------+
          |                                 |
     基础设施需求                         应用代码
          |                                 |
          v                                 v
     IaC Catalog                      Application Definition
          |                                 |
          v                                 v
     Terraform Plan                    Build Profile
          |                                 |
        Review                              CI
          |                    +------------+------------+
          v                    |            |            |
   Protected Apply           Build        Scan         Test
          |                    |            |            |
          v                    +------------+------------+
        Azure                               |
                                              v
                                       ACR Immutable Digest
                                              |
                                              v
                                       Release Request
                                              |
                                    +---------+---------+
                                    |                   |
                                   DEV                 TEST
                                    |                   |
                             gitops/dev          gitops/test
                                    |                   |
                                  Flux                 Flux
                                    |                   |
                                  AKS                 AKS
                                    |                   |
                                  Verify              Verify
                                    +---------+---------+
                                              |
                                             PROD
                                              |
                                       Approval / Lock
                                              |
                                         gitops/prod
                                              |
                                            Flux
                                              |
                                            AKS
                                              |
                                      Verify / Rollback
```

这套平台最终想解决的不是“怎么写一个 YAML”，而是：

**如何让大量研发团队在频繁修改代码和 Azure 基础设施时，仍然保持标准化、可审核、最小权限、制品可追溯、环境可晋级、故障可回滚。**
