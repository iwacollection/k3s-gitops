# IaC 模块封装、资源隔离与生产管理学习手册

> 目标：这不是一份“照着执行”的规范，而是一份帮助持续理解生产 IaC（Infrastructure as Code，基础设施即代码）设计思想的学习手册。
>
> 建议配合 `IaC-Governance-Production-Management.md`、`Terraform-Module治理规范.md`、`Terraform-Backend实施规范.md` 一起阅读：前者回答“应该怎么做”，本文重点回答“为什么这样做、错误做法会怎样、当前仓库对应在哪里”。

---

# 一、先建立一个最重要的认知：IaC 管理的不是代码，而是生产变更风险

很多人学习 Terraform 时，最先关注的是：

```text
resource 怎么写
variable 怎么写
module 怎么调
provider 怎么配
```

这些只是语法层。

生产 IaC 真正管理的是：

```text
一次基础设施变更
       |
       +-- 会改哪些资源？
       +-- 会不会误删？
       +-- 谁可以执行？
       +-- 执行的是不是审核过的计划？
       +-- 多个人同时执行怎么办？
       +-- Terraform State 出问题怎么办？
       +-- 已有资源怎么接管？
       +-- 重构代码会不会重建生产资源？
       +-- 环境之间会不会互相影响？
       +-- 出问题能不能回滚和恢复？
```

所以真正成熟的 IaC 体系，不只是“代码能创建 Azure 资源”，而是：

```text
代码
  +
State
  +
权限
  +
审批
  +
策略
  +
验证
  +
恢复机制
```

共同形成一个基础设施变更控制系统。

---

# 二、理解当前仓库的核心分层

当前仓库 Terraform 主要分为：

```text
infrastructure/terraform/
│
├── modules/
│   ├── network
│   ├── network-security
│   ├── nat-gateway
│   ├── aks
│   ├── container-registry
│   ├── key-vault
│   ├── database
│   ├── managed-redis
│   ├── monitoring
│   ├── private-endpoint
│   ├── private-dns
│   └── ...
│
└── environments/
    └── production/
        ├── backend.tf
        ├── provider.tf
        ├── main.tf
        ├── foundation.tf
        ├── database.tf
        ├── hardening.tf
        └── ...
```

这两层的角色不同。

## 1. modules：能力实现层

可以把 Module（模块）理解成“基础设施能力产品”。

例如：

```text
network module
= 怎么创建一套符合平台要求的网络

aks module
= 怎么创建一套符合平台要求的 AKS

database module
= 怎么创建一套符合平台要求的数据库
```

Module 应负责：

- 资源内部怎么创建
- 企业安全默认值
- 必要依赖
- 输入参数校验
- 输出稳定接口

Module 不应该负责：

- 生产环境专属账号
- 生产密码
- 生产订阅 ID
- 生产资源固定名称
- 某个环境的容量决策


## 2. environments：环境组装层

Environment（环境层）不是重新实现资源，而是决定：

```text
这个环境需要哪些模块
这些模块用什么参数
模块之间怎么连接
环境的容量是多少
环境的网络规划是什么
```

可以类比成：

```text
modules       = 零件厂
production    = 总装车间
```

当前 `production/foundation.tf` 就承担了这种“总装”作用：

```text
Network
  |
  +-- NSG
  +-- NAT Gateway
  +-- AKS
  +-- Monitoring
  +-- ACR
  +-- Key Vault
```

理解这一层以后，就能避免把所有资源都直接写进 `production/main.tf`。

---

# 三、Module 封装真正难的不是“拆文件”，而是确定边界

## 1. 什么不叫真正的模块化

下面这种结构并不等于真正模块化：

```text
modules/aks/
├── main.tf
├── variables.tf
└── outputs.tf
```

文件齐全只说明“格式像 Module”。

真正要回答的是：

```text
这个 Module 到底负责什么？
哪些东西归它负责？
哪些东西不能归它负责？
谁可以修改它？
调用者能控制哪些参数？
调用者不能控制哪些安全规则？
修改它会影响多少生产资源？
```


## 2. 一个好 Module 的四个边界

### 2.1 资源边界

一个 Module 应围绕一个稳定能力组织资源。

例如：

```text
network
├── VNet
├── AKS Subnet
├── Private Endpoint Subnet
└── Ingress Subnet
```

这些资源生命周期高度相关，可以放在同一个模块。

但是不要为了“代码少”把下面所有东西塞进一个超级模块：

```text
network
+ aks
+ database
+ redis
+ monitoring
+ key vault
+ policy
```

否则会形成“巨型 Module”。

巨型 Module 的问题：

- 变更影响范围太大
- 参数越来越多
- 单元测试困难
- 升级困难
- 某个资源需要替换时牵连全部逻辑


### 2.2 生命周期边界

适合放一起的资源通常具有相近生命周期。

例如：

```text
VNet + Subnet
```

通常一起规划、很少修改。

而：

```text
AKS Node Pool
```

可能经常升级、扩缩容。

这说明模块边界不仅按“资源类型”划分，还要看“变化频率”。


### 2.3 权限边界

如果某些资源需要完全不同的权限，可能应该拆开。

例如：

```text
普通网络资源
```

和：

```text
订阅级 RBAC
Azure Policy
Defender Pricing
```

后者通常需要更高权限。

如果全部塞进一个 Module，CI 身份往往被迫获得过大的权限。

这会违反 Least Privilege（最小权限原则）。

人话解释：

> 只给执行任务真正需要的权限，不要为了省事直接给 Owner。


### 2.4 故障影响范围边界

Blast Radius（故障影响范围）：一次错误能影响多大范围。

如果改一个模块可能同时替换：

```text
AKS
Database
Redis
Network
```

说明边界太大。

生产 IaC 的模块拆分目标之一，就是降低 Blast Radius。

---

# 四、不要把“通用”误解成“什么都能配置”

Terraform Module 最容易出现一个误区：

> 为了让模块通用，把 Azure Provider 的每一个参数都开放成 variable。

最后形成：

```text
var.enable_private_cluster
var.enable_oidc
var.enable_workload_identity
var.network_plugin
var.enable_monitoring
var.enable_rbac
var.outbound_type
var.enable_public_ip
var.xxx
var.yyy
...
```

一个 AKS Module 有几十甚至上百个参数。

这实际上相当于：

```text
Module
= Azure API 的二次转发层
```

调用者仍然必须懂 Azure 所有细节。

这不叫平台封装。


## 企业 Module 更合理的思路

企业 Module 应该提供有限、可控的业务参数：

```text
研发填写：

环境
节点规格
节点数量
业务名
容量等级
```

而平台 Module 自动决定：

```text
Private Cluster 是否强制开启
OIDC 是否强制开启
Workload Identity 是否开启
网络插件
日志配置
安全默认值
Tag
命名规则
加密规则
```

核心原则：

> 把业务选择留给使用者，把安全规则留给平台。

这叫 Opinionated Module，可以理解为“带平台约束的模块”。

生产中这种模块往往比“万能 Module”更安全。

---

# 五、当前 network Module 给出的一个重要学习点

当前 `modules/network` 默认包含：

```text
VNet
├── AKS Subnet
├── Private Endpoint Subnet
└── Ingress Subnet
```

并且默认规划了固定网段。

这说明它实际上更接近：

```text
AKS 平台标准网络模块
```

而不是完全通用的：

```text
Azure Network Module
```

这本身没有问题。

关键是模块名称和定位要与实际职责一致。

如果未来希望真正通用，可以把：

```text
10.60.0.0/16
10.60.0.0/22
10.60.4.0/24
10.60.5.0/24
```

从 Module 默认值逐步迁移到环境层：

```text
dev
10.80.0.0/16

staging
10.70.0.0/16

production
10.60.0.0/16
```

这样形成：

```text
Module
= 怎么建网络

Environment
= 这个环境建成什么样
```

---

# 六、variables.tf 本质上是 Module 的 API 合同

不要只把 `variable` 理解成“传参”。

可以这样理解：

```text
使用者
  |
  v
variables.tf
  |
  v
Terraform Module
  |
  v
Azure
```

`variables.tf` 相当于 API 请求接口。

所以一个生产级变量通常应该考虑：

```text
variable
├── type
├── description
├── default（确实合理才提供）
├── validation
└── sensitive
```


## 1. type：数据类型约束

避免：

```text
节点数量本应是数字
结果传入字符串
```


## 2. description：告诉调用者为什么存在

不要写：

```text
node_count = node count
```

更合理：

```text
生产 AKS 系统节点池节点数，必须满足高可用最低数量要求
```


## 3. default：默认值不能乱给

有些变量适合默认值：

```text
日志保留 30 天
```

有些不适合：

```text
生产数据库密码
生产 VNet 地址空间
```

错误的默认值容易被“无意识继承”。


## 4. validation：尽可能在 Plan 前阻断错误

不要等 Azure API 报错才发现参数非法。

例如：

```text
节点数不能小于 2
环境只能是 dev/staging/production
生产环境禁止 public_access = true
```

Terraform 应尽可能在自身校验阶段就失败。

原则：

> 能在代码入口阻止的错误，不要拖到云平台创建阶段。


## 5. sensitive：敏感输入必须显式标记

例如：

```text
数据库密码
Token
Secret
```

但是注意：

`sensitive = true` 只解决输出隐藏问题，并不自动等于“安全存储”。

真正的敏感信息仍应来自：

```text
GitHub Secret
Key Vault
OIDC
安全变量注入
```

---

# 七、outputs.tf 也是接口，不是“想输出什么就输出什么”

`outputs.tf` 相当于 Module 的返回值。

例如 network Module 可以稳定输出：

```text
vnet_id
aks_subnet_id
private_endpoint_subnet_id
ingress_subnet_id
```

AKS Module 可以输出：

```text
cluster_id
cluster_name
oidc_issuer_url
kubelet_object_id
```


## 为什么输出稳定性很重要

假设：

```text
AKS Module
    |
    +-- 输出 oidc_issuer_url
             |
             v
Workload Identity Module
```

如果随意删除或改名 output，就会影响调用方。

所以 Module 升级也存在“接口兼容性”。

真正成熟后，Module 应考虑版本管理：

```text
v1.0.0
v1.1.0
v2.0.0
```

特别是共享 Module 被多个项目使用时更重要。

---

# 八、环境隔离不是“建 dev/prod 两个文件夹”这么简单

完整的环境隔离至少有五层。

```text
环境隔离
│
├── 1. 代码入口隔离
│      dev/
│      staging/
│      production/
│
├── 2. Terraform State 隔离
│      dev.tfstate
│      staging.tfstate
│      production.tfstate
│
├── 3. Azure 资源隔离
│      Resource Group / Subscription
│
├── 4. 权限隔离
│      Dev Identity
│      Prod Plan Identity
│      Prod Apply Identity
│
└── 5. 发布流程隔离
       dev 自动
       staging 审核
       production 严格审批
```

其中最重要的是：

```text
State 隔离
权限隔离
```

文件夹隔离只是表面。

---

# 九、什么时候应该使用不同 Azure Subscription

Resource Group（资源组）隔离并不一定足够。

大型企业常见：

```text
Management Group
│
├── Non-Production Subscription
│   ├── dev
│   └── staging
│
└── Production Subscription
    └── production
```

Subscription（订阅）隔离的好处：

- 权限边界更强
- 配额独立
- 成本核算更清楚
- Azure Policy 更容易管理
- 非生产身份无法误操作生产
- 生产故障不会被测试环境配额消耗影响

并不是所有团队都需要一开始就拆订阅，但要理解：

> 环境越重要，隔离边界越应该靠近云平台账户层，而不是只靠目录约定。

---

# 十、Terraform State 是整个 IaC 系统最重要的资产之一

Terraform 实际工作时，不只是看代码。

它比较的是：

```text
Terraform Code
      +
Terraform State
      +
Azure 真实资源
```


## 1. State 是什么

State 可以理解成 Terraform 的“资产认知数据库”。

例如：

```text
azurerm_kubernetes_cluster.this
```

Terraform 必须知道它对应 Azure 中哪个真实资源 ID。

这个映射关系就在 State 中。


## 2. 为什么丢 State 很危险

Azure 资源可能还在：

```text
AKS 正常
Database 正常
VNet 正常
```

但是 Terraform 不知道它们是谁。

再次 Apply 时可能：

- 尝试重复创建
- 资源名冲突
- 产生错误差异
- 无法安全修改

因此：

> Git 丢了，可以从历史恢复；State 丢了，Terraform 与真实世界的关系就断了。


## 3. State 中可能包含敏感信息

State 可能保存：

- Resource ID
- IP
- Endpoint
- 配置属性
- 某些敏感字段

因此 State Backend 必须视为安全资产。

---

# 十一、Backend 为什么要独立保护

Backend（后端）就是 State 的远程存储位置。

当前生产采用 Azure Storage Backend，并已经考虑：

```text
Storage Account
├── TLS
├── 禁止 Public Blob
├── Versioning
├── Soft Delete
└── Terraform State Container
```

这是正确方向。


## 更进一步：Bootstrap 与普通 IaC 生命周期分离

Terraform 有一个经典“鸡生蛋”问题：

```text
Terraform 需要 Backend
       |
       v
但 Backend 本身也是 Azure 资源
```

常见解决方法：

```text
bootstrap/
├── Terraform State Storage
├── OIDC Identity
├── 基础 RBAC
└── GitHub Environment

production/
├── Network
├── AKS
├── Database
└── Redis
```

Bootstrap 是极低频变更。

普通 Production IaC 是持续变更。

这样可以防止：

```text
管理业务资源的 Terraform
反过来误删除自己的 State 存储
```

---

# 十二、State 应该怎么拆：既不能太大，也不能太碎

## 1. 一个巨型 State 的问题

如果：

```text
production.tfstate

包含：
VNet
AKS
Redis
PostgreSQL
Key Vault
ACR
DNS
LB
WAF
Monitoring
Policy
RBAC
Backup
```

长期会出现：

- 任意变更都锁整个 State
- Plan 越来越慢
- 权限越来越大
- 故障影响范围扩大
- 团队并行变更困难


## 2. 一个资源一个 State 也不对

如果变成：

```text
vnet.tfstate
subnet.tfstate
nsg.tfstate
nat.tfstate
aks.tfstate
redis.tfstate
postgres.tfstate
```

会产生大量跨 State 依赖：

```text
VNet State
  |
  v
Subnet State
  |
  v
AKS State
  |
  v
Identity State
```

系统变得非常脆弱。


## 3. 更合理的拆分原则

按三个维度综合判断：

```text
生命周期
+
权限边界
+
故障影响范围
```

例如未来可以考虑：

```text
production/
│
├── foundation/
│   ├── VNet
│   ├── Subnet
│   ├── NSG
│   ├── NAT
│   └── Private DNS
│
├── platform/
│   ├── AKS
│   ├── ACR
│   ├── Workload Identity
│   └── Monitoring
│
├── data/
│   ├── PostgreSQL
│   ├── Redis
│   ├── Private Endpoint
│   └── Backup
│
└── security/
    ├── Key Vault
    ├── Policy
    ├── Defender
    └── RBAC
```

对应：

```text
production-foundation.tfstate
production-platform.tfstate
production-data.tfstate
production-security.tfstate
```

注意：

> 这是一种未来演进思路，不是要求当前仓库立刻拆分。

在资源规模还较小时，过早拆 State 反而增加复杂度。

---

# 十三、Terraform 依赖图：Terraform 为什么知道先建谁

Terraform 不是简单按文件顺序执行。

比如：

```text
foundation.tf
main.tf
database.tf
```

文件名不会决定创建顺序。

Terraform 根据资源引用关系形成 Dependency Graph（依赖图）。

例如：

```text
module.network.aks_subnet_id
            |
            v
module.aks.subnet_id
```

Terraform 就知道：

```text
先创建 Network
再创建 AKS
```


## 显式依赖 depends_on

如果 Terraform 无法通过引用自动识别依赖，可以使用：

```text
depends_on
```

但是不要滥用。

因为大量手工 `depends_on` 往往说明模块接口设计有问题。

原则：

> 优先让资源之间通过真实输入输出关系建立依赖；只有隐藏依赖才使用 depends_on。

---

# 十四、生产 Plan 的核心价值：不是“看看会变什么”，而是风险审计

Terraform Plan 应关注：

```text
+ create
~ update
- destroy
-/+ replace
```

其中：

```text
replace
```

往往比普通 delete 更危险。

因为它代表：

```text
旧资源删除
+
新资源创建
```

对于以下资源尤其危险：

```text
Database
AKS
VNet
Subnet
Key Vault
Private Endpoint
```


## 为什么生产 Apply 应执行同一个 Plan

错误流程：

```text
10:00 terraform plan
       |
       v
人工审批
       |
       v
10:20 terraform apply
```

如果 Apply 重新计算，10:00 到 10:20 之间 Azure 状态发生变化：

```text
审核内容
!=
真正执行内容
```

更安全的模式：

```text
terraform plan -out=production.tfplan
        |
        v
审核 production.tfplan
        |
        v
terraform apply production.tfplan
```

原则：

> 审核什么，就执行什么。

---

# 十五、审批应该审批“具体变更”，不是只审批“运行流水线”

有两种审批思路。

## 较弱模式

```text
点击 Production Approval
       |
       v
流水线才开始 Plan
       |
       v
Apply
```

审批人只是批准“运行生产 Terraform”。


## 更成熟模式

```text
Pull Request
    |
    v
Terraform Plan
    |
    v
安全扫描
    |
    v
Policy Gate
    |
    v
生成变更摘要
+ 3 create
~ 2 update
- 0 delete
    |
    v
人工审批这个具体 Plan
    |
    v
Apply 同一份 Plan
```

这叫 Change Approval（变更审批）。

审批对象应该是“变更内容”，而不是“脚本执行权”。

---

# 十六、并发 Apply 为什么危险

假设两个 GitHub Actions 同时：

```text
Job A
terraform plan

Job B
terraform plan
```

然后同时 Apply。

可能出现：

```text
State 锁竞争
变更基线不同
资源冲突
后一份 Plan 已经过期
```

所以生产 Apply 需要 Concurrency（并发控制）。

当前仓库已经使用：

```text
concurrency group
cancel-in-progress = false
```

含义：

```text
生产 Apply A 正在执行
        |
生产 Apply B 到来
        |
        v
等待
```

而不是：

```text
取消 A
直接跑 B
```

对于 Terraform Apply，这个设计非常重要。

---

# 十七、prevent_destroy：让危险操作必须“显式化”

对于特别关键资源可以考虑：

```hcl
lifecycle {
  prevent_destroy = true
}
```

适合重点评估：

```text
生产数据库
Key Vault
核心 VNet
State Storage
Backup Vault
```

作用不是“资源永远不能删”。

而是：

```text
普通代码修改
       |
       X
不能顺手删除关键资源
```

如果真的需要删除：

```text
先明确修改保护
    |
    v
Pull Request
    |
    v
审批
    |
    v
再执行删除
```

核心思想：

> 危险操作必须从“意外发生”变成“明确决策”。

---

# 十八、已有 Azure 资源纳管：不是重新创建，而是让 Terraform 认领

这类场景非常常见：

```text
公司已经运行三年
突然决定使用 Terraform
```

错误思路：

```text
重新用 Terraform 创建一套
```

正确思路：

```text
现有 Azure Resource
        |
        v
Terraform Resource 定义
        |
        v
terraform import
        |
        v
Terraform State
        |
        v
terraform plan
        |
        v
No Changes
```

这叫 Adoption（纳管/接管）。


## 纳管的关键标准

最终第一次 Plan 最理想是：

```text
No changes
```

如果看到：

```text
- destroy
-/+ replace
```

必须暂停。

常见原因：

- Terraform 参数没写全
- Azure 默认值与代码不一致
- Provider 行为差异
- 资源历史配置特殊
- 实际资源已经漂移

---

# 十九、Terraform 重构为什么比普通代码重构危险

普通代码：

```text
函数 rename
```

大多数情况下只是代码地址变了。

Terraform 里：

```hcl
resource "azurerm_xxx" "old" {}
```

改成：

```hcl
resource "azurerm_xxx" "new" {}
```

Terraform 可能理解为：

```text
old 不存在了 -> 删除
new 出现了   -> 创建
```

即使真实 Azure 资源完全没有变化。


## moved block

Terraform 提供 moved block 来告诉 Terraform：

```text
资源没有变
只是 Terraform 地址变了
```

适用：

- resource 重命名
- module 重命名
- 资源迁移到 Module
- Module 目录重构

生产 IaC 重构必须理解这一点。

原则：

> 整理代码不能成为重建生产资源的理由。

---

# 二十、Import、Moved、State Move 三者要区分

## Import

解决：

```text
Azure 有资源
Terraform 不认识
```


## Moved

解决：

```text
Terraform 已经认识资源
但代码地址改了
```


## terraform state mv

解决：

```text
手工调整 State 中的 Terraform 地址
```

新项目优先考虑声明式 `moved`，因为变更可以进入 Git、可审计。

`terraform state mv` 更偏运维修复操作，需要更谨慎。

---

# 二十一、Tag 不是装饰，而是云资源治理索引

Tag（标签）常被低估。

生产 Tag 至少可以用于：

```text
成本归属
环境识别
业务归属
负责人
合规扫描
自动清理
CMDB 同步
故障查询
```

推荐形成统一 Mandatory Tags（强制标签）：

```text
environment
project
owner
managed_by
cost_center
```

Module 不应该依赖调用者每次手写。

更合理的是：

```text
平台 Mandatory Tags
        +
业务自定义 Tags
        |
        v
merge
```

并通过：

```text
Terraform validation
CI Policy Gate
Azure Policy
```

多层保证。

原则：

> 文档要求的治理规则，最终应该尽可能变成机器可执行规则。

---

# 二十二、Policy Gate：把“规范”变成机器强制执行

文档里写：

```text
禁止公网数据库
禁止公网 Key Vault
必须加 Tag
```

只能叫“规范”。

如果 CI 自动检测并阻止：

```text
Terraform Plan
       |
       v
JSON
       |
       v
Policy
       |
       +-- Allow
       |
       +-- Reject
```

才真正形成治理。

这类机制通常叫 Policy as Code（策略即代码）。

人话解释：

> 把安全制度写成程序，让机器在发布前自动拦截。

---

# 二十三、Drift：为什么禁止直接改 Azure Portal

Drift（配置漂移）表示：

```text
Terraform Code
       !=
Azure 真实资源
```

例如有人手工：

```text
Azure Portal
把 NSG 开了 0.0.0.0/0
```

代码没变。

这就产生 Drift。

下一次 Terraform Plan 可能：

```text
准备把手工修改恢复
```

也可能因为复杂资源行为产生更大的差异。

因此生产环境原则：

```text
Git 为变更入口
Portal 主要用于观察和应急
```

如果紧急事故必须手工修改：

```text
先止血
    |
    v
记录操作
    |
    v
马上回补 Terraform
    |
    v
Plan 校准
```

不能长期让“真实配置”和“代码配置”分叉。

---

# 二十四、Provider 升级为什么也属于生产变更

很多人认为：

```text
只升级 azurerm Provider
没有改资源代码
所以没风险
```

这是错误的。

Provider（提供程序）负责把 Terraform 配置翻译成 Azure API 请求。

Provider 升级可能改变：

- 默认值
- 字段行为
- ForceNew（修改后必须重建）规则
- API 版本
- Deprecated 字段
- State Schema

所以 Provider 升级必须：

```text
升级版本
   |
   v
terraform init -upgrade
   |
   v
完整 Plan
   |
   v
重点检查 Replace/Delete
   |
   v
测试环境验证
   |
   v
生产发布
```

`.terraform.lock.hcl` 应提交到 Git，用来固定实际 Provider 版本。

---

# 二十五、Module 版本治理：以后共享模块时必须理解

当前仓库 Module 与 Environment 在同一个 Git 仓库中，可以直接：

```text
source = "../../modules/aks"
```

优点：

- 修改简单
- 统一提交
- 当前规模适合

未来如果多个仓库共同使用 Module，可能演进成独立 Module 仓库：

```text
terraform-azure-aks-module
terraform-azure-network-module
```

使用版本：

```text
v1.2.0
v1.3.0
v2.0.0
```

这样应用仓库不会因为 Module 最新代码变化自动受到影响。

核心原则：

> 共享模块必须版本化，否则一次模块修改可能同时影响多个生产环境。

---

# 二十六、命名规范为什么也应该代码化

不建议每个调用者自己写：

```text
k3s-production-aks
k3s-production-vnet
k3s-production-redis
```

长期容易出现：

```text
prod-aks
aks-prod
production-aks
k3s-aks-prod
```

成熟做法可以形成 Naming Module / Naming Local：

```text
project
+
environment
+
resource_type
+
region
```

统一生成资源名。

注意 Azure 不同资源命名限制不同，例如：

- ACR 不能使用连字符
- Storage Account 长度有限
- Key Vault 名称需要全局唯一

所以命名逻辑最好集中管理，不要到处复制字符串。

---

# 二十七、Resource Group 应如何理解

Resource Group（资源组）不是单纯的“文件夹”。

它同时是：

```text
资源生命周期边界
权限作用域
Policy 作用域
成本查询边界
运维管理边界
```

因此不应只按“看起来整齐”划分。

可以按：

```text
系统
生命周期
团队
环境
权限
```

综合设计。

例如：

```text
rg-platform-production
rg-data-production
rg-security-production
```

是否需要拆，取决于资源规模和组织职责。

当前项目规模较小时，一个生产 Resource Group 更简单；后续增长后再评估。

---

# 二十八、Plan Identity 与 Apply Identity 为什么最好分开

Plan 只需要：

```text
读取资源
读取 State
计算差异
```

Apply 需要：

```text
创建
修改
删除
RBAC
Policy
```

如果二者使用同一个高权限身份：

```text
任何 PR Plan
都拥有生产写权限
```

攻击面更大。

更合理：

```text
Plan Identity
= 低权限、只读为主

Apply Identity
= 生产写权限、只允许受保护环境使用
```

这是 Separation of Duties（职责分离）。

人话解释：

> 看变更的人不一定要拥有真正修改生产的权力。

---

# 二十九、OIDC 为什么优于长期 Client Secret

传统：

```text
GitHub Secret
保存 Azure Client Secret
```

风险：

- 长期存在
- 可能泄露
- 需要轮换
- Secret 被复制后仍可使用

OIDC（OpenID Connect，开放身份连接）模式：

```text
GitHub Actions
      |
      v
短期 OIDC Token
      |
      v
Azure Federated Identity
      |
      v
临时认证
```

优点：

- 无长期密码
- Token 短期有效
- 可以绑定仓库、分支、Environment
- 审计更清楚

但是 OIDC 不等于权限自动安全。

如果 OIDC 对应身份直接拥有 Owner，仍然是高风险。

所以必须同时做最小权限。

---

# 三十、生产 IaC 的三层防误删模型

不要只依赖一种保护。

## 第一层：代码级保护

```text
prevent_destroy
validation
模块安全默认值
```


## 第二层：CI 级保护

```text
Plan delete 检测
Replace 检测
Policy Gate
人工审批
Concurrency
```


## 第三层：Azure 级保护

```text
Resource Lock
RBAC
Azure Policy
Backup
Soft Delete
```

三层共同存在时，单点失误才不容易造成事故。

原则：

> 生产安全不能依赖“工程师不会犯错”。

---

# 三十一、为什么 Apply 后还必须验证

Terraform Apply 成功只代表：

```text
Azure API 接受了 Terraform 请求
```

不代表业务真正可用。

例如：

```text
AKS 创建成功
但 Node NotReady

Private Endpoint 创建成功
但 DNS 解析错误

ACR 存在
但 AKS 没有 AcrPull

Database 存在
但网络访问失败
```

所以需要 Post Apply Verification（应用后验证）。

至少包括：

```text
资源存在
网络连通
RBAC 正确
节点 Ready
DNS 正确
监控上线
关键依赖可访问
```

当前仓库生产 Apply 后已经有 Azure 资源和 Kubernetes 节点检查，这个方向应该保留。

---

# 三十二、IaC 回滚和应用回滚不是一回事

应用发布通常可以：

```text
v2 -> v1
```

Terraform 不一定能简单：

```text
git revert
terraform apply
```

因为一些资源变更是不可逆或有数据风险的。

例如：

```text
数据库版本升级
VNet 地址变化
资源替换
磁盘缩容
```

所以 IaC 的恢复思想应该是：

```text
变更前 Plan 风险评估
+
资源级 Backup
+
State Versioning
+
Azure Soft Delete
+
明确恢复步骤
```

不是把“Git 回退”当万能回滚。

---

# 三十三、生产 IaC 变更应该怎样思考

每一次 Terraform 变更，在执行前都应该问：

```text
1. 这次改了什么？
2. 为什么要改？
3. 影响哪些资源？
4. 是否包含 Replace？
5. 是否包含 Delete？
6. 是否影响网络？
7. 是否影响数据？
8. 是否需要停机？
9. 是否有备份？
10. 如果失败，怎么恢复？
11. Apply 后验证什么？
12. 是否会产生 Drift？
```

这套思维比背 Terraform 命令更重要。

---

# 三十四、当前仓库后续值得持续改进的方向

以下内容不是要求一次性全部实施，而是后续演进清单。

## P1：优先理解并逐步加强

```text
Module variable validation
关键资源 prevent_destroy
统一 Mandatory Tags
Replace 风险检测
模块接口 description
```


## P2：资源规模扩大后评估

```text
dev / staging / production 完整环境层
按生命周期拆 Production State
Bootstrap 独立
Plan 与 Apply 权限进一步隔离
Production Plan Artifact 审批
```


## P3：平台化以后考虑

```text
共享 Module 独立版本仓库
Module 自动测试
Terraform Test
Terratest
成本策略 Gate
CMDB 自动同步
资源生命周期自动审计
```

---

# 三十五、常见错误经验总结

## 错误 1：一个 main.tf 写整个生产环境

后果：

- 难维护
- 难复用
- 变更范围不清晰

正确：

```text
Module 实现
Environment 组装
```


## 错误 2：Module 什么参数都开放

后果：

- 调用方仍然必须懂云平台
- 安全策略容易被关闭

正确：

```text
开放业务参数
固定平台安全规则
```


## 错误 3：所有资源一个 State

后果：

- 锁范围大
- 权限大
- Blast Radius 大

正确：

资源增长后按生命周期、权限、风险逐步拆。


## 错误 4：一个资源一个 State

后果：

- 跨 State 依赖爆炸
- remote state 到处引用

正确：

保持高内聚。


## 错误 5：Terraform 已有资源直接 Apply

后果：

- 冲突
- 重建
- 删除风险

正确：

```text
定义 -> Import -> Plan 0 change -> 纳管
```


## 错误 6：代码重命名直接提交

后果：

Terraform 可能认为旧资源删除、新资源创建。

正确：

使用 moved / State Migration。


## 错误 7：审批后重新 Plan

后果：

审核内容与执行内容可能不同。

正确：

Apply 审核过的同一个 Plan Artifact。


## 错误 8：只靠 Terraform 防误删

后果：

单层保护失效就可能事故。

正确：

```text
Terraform
+
CI
+
Azure
```

三层保护。


## 错误 9：Provider 随便升级

后果：

可能出现大量 Drift 或 ForceNew。

正确：

固定版本、独立升级、完整 Plan。


## 错误 10：Apply 成功就认为上线成功

后果：

资源存在但业务不可用。

正确：

Post Apply Verification。

---

# 三十六、面试时可以怎么回答“Terraform 生产治理”

可以用下面这条主线回答：

```text
我不会把 Terraform 只当资源创建工具，
而是当生产基础设施变更控制系统。

第一层是 Module，
把网络、AKS、数据库等能力封装，
并固化安全默认值。

第二层是 Environment，
管理 dev、staging、production 的参数和组装关系。

第三层是 State，
不同环境必须隔离，
规模扩大以后再按生命周期、权限和故障影响范围拆 State。

第四层是 CI/CD，
所有变更必须经过 fmt、validate、security scan、plan、policy、approval，
Apply 必须执行审核过的同一份 Plan。

第五层是安全控制，
通过 OIDC、最小权限、concurrency、prevent_destroy、delete/replace Gate、Azure Policy 等避免误操作。

对于已有资源，不会重新创建，
而是通过 import 纳管，并要求第一次 plan 尽量做到 0 change。

对于 Terraform 重构，会通过 moved/state migration 保证代码重构不导致生产资源重建。

最后 Apply 成功以后还会做资源、网络、RBAC 和 Kubernetes Ready 状态验证。
```

这比单纯回答：

```text
我会写 Terraform Module
```

更能体现生产经验。

---

# 三十七、最终记忆模型

以后看到任何 Terraform 项目，可以先用这棵树判断成熟度：

```text
生产 IaC
│
├── Module
│   ├── 边界是否清晰
│   ├── 是否有安全默认值
│   ├── 输入是否校验
│   └── 输出是否稳定
│
├── Environment
│   ├── dev
│   ├── staging
│   └── production
│
├── State
│   ├── Remote Backend
│   ├── Lock
│   ├── Version
│   ├── Backup
│   └── Blast Radius
│
├── Identity
│   ├── OIDC
│   ├── Plan Identity
│   ├── Apply Identity
│   └── Least Privilege
│
├── Change
│   ├── fmt
│   ├── validate
│   ├── plan
│   ├── security
│   ├── policy
│   ├── approval
│   └── same-plan apply
│
├── Protection
│   ├── prevent_destroy
│   ├── delete/replace gate
│   ├── concurrency
│   ├── Azure Lock
│   └── Backup
│
├── Adoption
│   ├── Inventory
│   ├── Import
│   └── No Changes
│
├── Refactor
│   ├── moved
│   ├── import
│   └── state migration
│
└── Verification
    ├── Resource
    ├── Network
    ├── RBAC
    ├── DNS
    └── Runtime Health
```

最终要记住的不是几十个 Terraform 关键字，而是这一句话：

> **Git 描述期望状态，State 保存 Terraform 对资源的认知，Azure 是真实状态；生产 IaC 的所有治理机制，都是为了让这三者在可审计、可控制、可恢复的前提下安全收敛。**
