# k3s-gitops｜Azure 生产级 Terraform IaC 治理仓库

> **一眼看懂：这个仓库不是“放 Terraform 文件的地方”，而是生产基础设施的变更控制系统。**
>
> 核心目标：**任何生产基础设施变化，都必须可审查、可验证、可阻断、可审批、可追溯、可恢复。**

---

## 1. 先看这一张图

```text
                         Git / Pull Request
                                  │
                                  ▼
                    ┌────────────────────────┐
                    │  Terraform 代码变更    │
                    └───────────┬────────────┘
                                │
             ┌──────────────────┼──────────────────┐
             ▼                  ▼                  ▼
        fmt / validate       Checkov          Policy Gate
        代码质量              安全基线          变更风险
             │                  │                  │
             └──────────────────┼──────────────────┘
                                ▼
                         Terraform Plan
                                │
                                ▼
                     人工 Plan Review / Approval
                                │
                         ┌──────┴──────┐
                         │             │
                       Reject        Approve
                         │             │
                         ▼             ▼
                       修复       GitHub Actions
                                       │
                                       ▼
                               Azure OIDC 登录
                                       │
                                       ▼
                               Terraform Apply
                                       │
                                       ▼
                          Azure / Kubernetes 验证
                                       │
                                       ▼
                              记录 / 审计 / 回滚
```

### 你只需要记住 6 个词

| 概念 | 人话解释 | 解决的问题 |
|---|---|---|
| **Git** | 期望的基础设施配置 | 谁改了什么 |
| **Terraform State** | Terraform 认为资源是谁 | 配置与真实资源如何映射 |
| **Plan** | 这次准备做什么 | Apply 前看清变化 |
| **Policy Gate** | 哪些变化绝对不能做 | 自动拦截高风险操作 |
| **Approval** | 人是否同意承担这次变更 | 生产责任边界 |
| **Apply** | 真正修改 Azure | 执行生产变更 |

---

# 2. 仓库负责什么

本仓库统一管理 Azure 生产环境基础设施，包括：

### Kubernetes

- Azure Kubernetes Service（AKS）
- Node Pool
- Azure CNI
- OIDC / Workload Identity
- Ingress / Application Gateway

### 网络

- Virtual Network（VNet）
- Subnet
- Network Security Group（NSG）
- NAT Gateway
- Load Balancer
- Private Endpoint
- Private DNS

### 数据与平台服务

- PostgreSQL Flexible Server
- Azure Cache for Redis
- Azure Container Registry（ACR）
- Azure Key Vault

### 可观测性与安全

- Log Analytics
- Diagnostic Settings
- Azure Monitor
- Defender for Cloud
- Azure Policy

---

# 3. 目录结构：每个目录到底干什么

```text
k3s-gitops/
│
├── infrastructure/
│   └── terraform/
│       │
│       ├── environments/
│       │   └── production/
│       │       ├── backend.tf              # State 后端
│       │       ├── provider.tf             # Azure Provider
│       │       ├── main.tf                 # 生产环境入口
│       │       ├── foundation.tf           # 基础设施
│       │       ├── database.tf             # 数据服务
│       │       ├── hardening.tf             # 安全加固
│       │       ├── quota.tf                 # 配额治理
│       │       └── outputs.tf               # 输出
│       │
│       └── modules/
│           ├── aks/                         # AKS 模块
│           ├── network/                     # 网络模块
│           ├── database/                    # 数据库模块
│           ├── security/                    # 安全模块
│           └── monitoring/                  # 监控模块
│
├── policy/
│   └── terraform/
│       └── terraform.rego                  # OPA/Conftest Policy Gate
│
├── .github/
│   ├── CODEOWNERS                           # 关键目录负责人
│   └── workflows/                           # CI/CD 与生产保护
│
├── docs/                                    # 生产治理与学习文档
├── README.md                                # 从这里开始
└── SECURITY.md                              # 安全报告规范
```

### 最重要的边界

```text
modules
   ↓
“怎么创建一种资源”

production
   ↓
“生产环境到底使用什么”

policy
   ↓
“什么事情禁止做”

.github/workflows
   ↓
“什么条件下才能进入下一阶段”

docs
   ↓
“为什么这样管理、出了问题怎么办”
```

**这五层不要混在一起。**

---

# 4. 生产变更标准

## 禁止这样做

```text
开发者电脑
   ↓
terraform apply
   ↓
生产 Azure
```

也禁止：

- 直接修改生产 Azure 资源后不回写 Terraform
- 删除 Terraform State 文件
- 为了让 CI 通过直接关闭安全检查
- 永久 Policy 豁免
- 未经过 Plan Review 直接 Apply
- 用长期 Azure Secret 登录生产

---

# 5. 标准生产流程

```text
① 修改 Terraform
       ↓
② Pull Request
       ↓
③ fmt
       ↓
④ validate
       ↓
⑤ TFLint
       ↓
⑥ Checkov
       ↓
⑦ Terraform Plan
       ↓
⑧ Plan JSON
       ↓
⑨ Policy Gate
       ↓
⑩ 人工 Review
       ↓
⑪ Production Approval
       ↓
⑫ Azure OIDC
       ↓
⑬ Terraform Apply
       ↓
⑭ Azure/Kubernetes 验证
       ↓
⑮ 记录与审计
```

任何一个关键阶段失败，都应该停止，而不是继续向下执行。

---

# 6. Policy Gate：生产最重要的机器防线之一

## 6.1 它到底解决什么问题？

假设 Terraform 代码本身完全合法：

```hcl
resource "azurerm_postgresql_flexible_server" "main" {
  public_network_access_enabled = true
}
```

Terraform 可能认为：

```text
语法正确
Provider 正确
配置合法
```

但生产治理认为：

```text
数据库公网暴露
        ↓
风险过高
        ↓
禁止进入 Apply
```

所以：

> **“Terraform 能执行” ≠ “生产允许执行”。**

Policy Gate 就是把公司的生产规则变成机器可以执行的规则。

---

# 7. 当前 Policy Gate 规则

策略代码位于：

```text
policy/terraform/terraform.rego
```

当前生产阻断规则：

| 编号 | 规则 | 默认动作 |
|---|---|---|
| **PG001** | 禁止生产资源 Delete | BLOCK |
| **PG002** | 禁止核心资源 Replace | BLOCK |
| **PG003** | 禁止 Owner RBAC | BLOCK |
| **PG004** | 禁止 Contributor RBAC | BLOCK |
| **PG005** | Storage 禁止公网访问 | BLOCK |
| **PG006** | PostgreSQL 禁止公网访问 | BLOCK |
| **PG007** | 关键生产资源必须有 Tag | BLOCK |
| **PG008** | NSG 高风险管理端口禁止公网开放 | BLOCK |
| **PG009** | 未知 Terraform Action 默认失败 | BLOCK |

完整规则解释：

**[`docs/Terraform-Policy-Gate规范.md`](docs/Terraform-Policy-Gate规范.md)**

---

# 8. 为什么需要“代码扫描 + Plan Policy”两层

它们不是重复的。

```text
Checkov
   ↓
检查 Terraform 配置是否违反常见安全基线

Terraform Plan
   ↓
检查这一次实际准备发生什么

Policy Gate
   ↓
检查这一次变化是否符合生产规则
```

例如：

```text
Terraform 代码
      ↓
Checkov PASS
      ↓
Plan 发现：核心 AKS 要被重建
      ↓
PG002 BLOCK
```

这就是为什么生产 IaC 不能只有 Checkov。

---

# 9. Policy Gate 为什么看 Plan JSON

`.tf` 文件告诉我们：

```text
“我写了什么”
```

Plan 告诉我们：

```text
“Terraform 准备怎么改变基础设施”
```

所以 Policy Gate 的输入是：

```text
terraform plan
       ↓
terraform show -json
       ↓
tfplan.json
       ↓
Conftest / OPA
```

最终策略判断的是：

```text
resource_changes
      ↓
create / update / delete
      ↓
具体资源
      ↓
具体风险
```

---

# 10. Fail Closed：无法判断也不能默认放行

安全系统必须遵守：

```text
明确允许 → PASS
明确禁止 → BLOCK
无法判断 → BLOCK
```

而不是：

```text
无法判断 → PASS
```

原因很简单：

```text
Terraform / Azure 新增资源能力
        ↓
Policy 暂时不认识
        ↓
如果默认 PASS
        ↓
新风险直接进入生产
```

因此 PG009 专门保护这个边界。

---

# 11. State 管理

Terraform State 是生产核心资产。

```text
Git
 = 期望配置

State
 = Terraform 与资源的映射

Azure
 = 实际资源状态
```

生产目标：

```text
Git
 │
 ▼
Terraform State
 │
 ▼
Azure
```

必须使用远程 Backend，并具备：

- State 锁
- 版本历史
- 恢复能力
- 访问权限控制

禁止使用本地 `terraform.tfstate` 作为生产唯一 State。

---

# 12. 已有 Azure 资源如何接管

不能因为 Azure 已经存在，就重新创建。

正确流程：

```text
Azure 已有资源
       ↓
资源盘点
       ↓
编写 Terraform Resource
       ↓
terraform import
       ↓
terraform plan
       ↓
校准配置
       ↓
No changes
       ↓
正式纳管
```

如果第一次 Plan 出现：

```text
-/+
```

或者：

```text
destroy
create
replace
```

**不要直接 Apply。**

先判断是：

- Terraform 配置不完整
- Provider 参数不一致
- State 映射错误
- ForceNew 导致重建
- Azure 实际状态与代码不一致

---

# 13. 权限模型

生产采用最小权限原则。

```text
开发人员
   │
   ├── GitHub PR
   └── Azure Reader

GitHub Actions
   │
   └── Azure OIDC

Production Apply
   │
   └── 受控身份 + Approval
```

禁止：

- 长期 Azure Client Secret
- Access Key
- 共享管理员账号
- 开发人员直接生产 Apply

---

# 14. 为什么还需要 Azure Policy

Terraform Policy Gate 不是最后一道防线。

应该形成纵深防御：

```text
GitHub
  ↓
PR Policy Gate
  ↓
Approval
  ↓
Terraform Apply
  ↓
Azure Policy
  ↓
Azure Resource
```

### Terraform Policy Gate

防止：

> **错误代码进入生产。**

### Azure Policy

防止：

> **即使有人绕过 Terraform，危险资源状态仍然可以被平台控制。**

---

# 15. Drift：人工修改怎么办

生产资源禁止人工修改作为常规操作。

如果 Azure 实际状态发生变化：

```text
Git Terraform
      ≠
Azure 实际状态
```

就产生 Drift（配置漂移）。

处理方式：

```text
发现 Drift
    ↓
判断变化来源
    ↓
业务紧急变更？
    │
    ├── 是 → 补齐 Terraform + 审计
    │
    └── 否 → 恢复 Terraform 期望状态
```

不能简单理解为：

```text
terraform plan 有变化
→ 直接 apply
```

必须先知道为什么产生变化。

---

# 16. 高风险变更分类

生产变更至少分成：

### 低风险

```text
Tag
描述
非关键监控参数
```

### 中风险

```text
Node Pool 扩容
监控调整
非关键网络规则
```

### 高风险

```text
生产数据库
AKS 核心配置
VNet / Subnet
Private Endpoint
RBAC
公网暴露
删除 / Replace
```

高风险变更必须经过更严格的 Review 和 Approval。

---

# 17. Policy 豁免不是“关闭检查”

禁止：

```text
为了让 CI 通过
↓
删除 Policy
```

正确做法：

```text
Policy 触发
   ↓
确认业务确实需要
   ↓
风险评估
   ↓
补偿控制
   ↓
负责人审批
   ↓
关联 Issue / PR
   ↓
设置过期时间
   ↓
到期重新评估
```

任何生产豁免都必须可追溯。

---

# 18. 文档从哪里看

推荐顺序：

```text
README.md
   ↓
docs/README.md
   ↓
IaC-模块封装资源隔离与生产管理学习手册.md
   ↓
IaC-Governance-Production-Management.md
   ↓
Terraform-Policy-Gate规范.md
   ↓
Terraform-Module治理规范.md
   ↓
Terraform-Backend实施规范.md
   ↓
Resource保护策略与漂移检测规范.md
```

### 如果你只想学 Policy Gate

直接：

```text
README.md
   ↓
Terraform-Policy-Gate规范.md
   ↓
policy/terraform/terraform.rego
   ↓
.github/workflows/terraform-security-governance.yml
```

这四个文件就是完整闭环：

```text
为什么要做
    ↓
规则是什么
    ↓
规则怎么写
    ↓
CI 怎么执行
```

---

# 19. 生产 IaC 的最终心智模型

不要把这个仓库理解成：

```text
Terraform 文件集合
```

应该理解成：

```text
                 ┌──────────────┐
                 │    Git       │
                 │  期望状态    │
                 └──────┬───────┘
                        │
                        ▼
                 ┌──────────────┐
                 │ Terraform    │
                 │   Plan       │
                 └──────┬───────┘
                        │
                        ▼
                 ┌──────────────┐
                 │ Policy Gate  │
                 │  风险阻断    │
                 └──────┬───────┘
                        │
                        ▼
                 ┌──────────────┐
                 │   Approval   │
                 │  人工责任    │
                 └──────┬───────┘
                        │
                        ▼
                 ┌──────────────┐
                 │    Apply     │
                 └──────┬───────┘
                        │
                        ▼
                 ┌──────────────┐
                 │ Azure / K8s  │
                 │   真实状态   │
                 └──────┬───────┘
                        │
                        ▼
                 ┌──────────────┐
                 │ Drift /      │
                 │ Verification │
                 └──────────────┘
```

最终形成：

> **声明 → Plan → Policy → Approval → Apply → Verify → Drift Detection → 治理**

这才是生产级 IaC 的完整闭环。

---

## 20. 生产原则速记

```text
Terraform = 基础设施声明
Git       = 变更事实
State     = 资源映射事实
Plan      = 变更风险评估
Policy    = 自动风控
Approval  = 人工责任边界
Apply     = 受控执行
Verify    = 结果确认
Drift     = 偏离治理
Azure     = 最终运行状态
```

**任何一个环节缺失，都可能让“代码正确”变成“生产事故”。**
