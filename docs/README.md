# IaC 文档中心｜先看这里

> **目标：不是把文档写成“命令大全”，而是让任何人打开仓库 5 分钟内知道：资源在哪里、谁负责、怎么变更、什么会被阻断、失败怎么处理。**

---

# 1. 一张图看懂整个仓库

```text
                    ┌──────────────────┐
                    │ 需求 / 变更申请    │
                    └────────┬─────────┘
                             ↓
                    Terraform Environment
                             ↓
                       Terraform Module
                             ↓
                         Pull Request
                             ↓
        ┌────────────────────┼────────────────────┐
        ↓                    ↓                    ↓
   Quality Gate        Security Gate         Secret Gate
        │                    │                    │
        └────────────────────┼────────────────────┘
                             ↓
                       Terraform Plan
                             ↓
                       Plan JSON Evidence
                             ↓
                        Policy Gate
                             ↓
                      风险分级 / Review
                             ↓
                     Production Approval
                             ↓
                       OIDC + RBAC
                             ↓
                      Terraform Apply
                             ↓
                    Post-Apply Verification
                             ↓
                      Drift Detection
                             ↓
                    审计 / 持续治理
```

---

# 2. 目录和职责

```text
k3s-gitops/
│
├── infrastructure/
│   └── terraform/
│       ├── modules/                 # “怎么创建”
│       └── environments/            # “这个环境创建什么”
│
├── policy/
│   └── terraform/                  # “什么变更不允许”
│
├── .github/
│   ├── workflows/                  # “检查和执行怎么自动化”
│   └── CODEOWNERS                   # “谁必须Review”
│
├── docs/                            # “为什么这样设计”
│
└── README.md                        # “仓库入口”
```

记忆方法：

```text
Module      = 能力
Environment = 实例
State       = 映射
Policy      = 规则
Workflow    = 流程
Approval    = 责任
Verification= 结果
```

---

# 3. 如果你第一次看仓库

按这个顺序，不要从 Terraform 文件开始乱看：

### 第 1 步：根 README

先回答：

- 仓库管理什么？
- 生产变更怎么走？
- 哪些资源是核心资源？
- 哪些操作禁止？

### 第 2 步：本文件

理解整个文档地图。

### 第 3 步：生产治理

阅读：

`IaC-Governance-Production-Management.md`

重点理解：

```text
责任边界
资源生命周期
变更风险
State
权限
Approval
Verification
Drift
```

### 第 4 步：Module

阅读：

`Terraform-Module治理规范.md`

理解“基础设施能力怎么封装”。

### 第 5 步：Backend / State

阅读：

`Terraform-Backend实施规范.md`

理解“Terraform 如何知道代码对应哪个真实资源”。

### 第 6 步：代码扫描

阅读：

`Terraform-代码扫描规范.md`

理解“代码进入 Plan 前怎么被检查”。

### 第 7 步：Policy Gate

阅读：

`Terraform-Policy-Gate规范.md`

理解“什么变化绝对不允许进入生产”。

### 第 8 步：CI

阅读：

`IaC-CI验证流程规范.md`

把前面所有规则串成实际流水线。

### 第 9 步：保护与漂移

阅读：

`Resource保护策略与漂移检测规范.md`

理解“执行以后如何保护和发现异常”。

### 第 10 步：OIDC

阅读：

`Terraform-Azure-OIDC无密认证规范.md`

理解“CI 到 Azure 到底以什么身份执行”。

---

# 4. 按“问题”找文档

| 你遇到的问题 | 第一份应该看什么 | 还要看什么 |
|---|---|---|
| Terraform 应该怎么组织？ | Module治理 | 生产治理 |
| 已有 Azure 资源怎么接管？ | Backend实施 | Import清单 |
| 为什么 Plan 要删除资源？ | Resource保护 | Backend / Module |
| 为什么突然 Replace？ | Resource保护 | Module治理 |
| 什么安全配置不能进生产？ | Policy Gate | 代码扫描 |
| 谁能 Apply？ | OIDC | CI / Production治理 |
| 为什么 CI 失败？ | CI验证流程 | 代码扫描 / Policy |
| 资源被 Portal 改了怎么办？ | Drift | 生产治理 |
| State 丢了怎么办？ | Backend实施 | 灾难恢复 |
| Resource 名称和 Tag 怎么定？ | 命名与Tag | Module治理 |
| Apply 后怎么证明成功？ | CI验证流程 | Post-Apply workflow |
| 生产事故怎么处理？ | 生产治理 | Resource保护 / DR |

---

# 5. 每份规范必须回答什么

以后新增任何治理文档，都必须至少回答：

```text
① 是什么？
② 为什么需要？
③ 解决什么生产问题？
④ 适用范围是什么？
⑤ 标准流程是什么？
⑥ 谁负责？
⑦ CI 如何自动检查？
⑧ 什么情况阻断？
⑨ 失败怎么处理？
⑩ 怎么回滚？
⑪ 怎么验证？
⑫ 怎么审计？
⑬ 大规模以后怎么演进？
```

不能只写：

```text
执行 terraform xxx
```

必须说明：

```text
为什么执行
 ↓
执行前检查什么
 ↓
会改变什么
 ↓
可能有什么风险
 ↓
失败如何止损
 ↓
恢复后如何验证
```

---

# 6. 文档与代码必须能互相定位

治理规则不能只存在于文字里。

推荐映射：

```text
文档规则
   ↕
Policy ID
   ↕
Rego规则
   ↕
Workflow
   ↕
CI结果
```

例如：

```text
PG002
“禁止核心资源 Replace”
        ↓
policy/terraform/terraform.rego
        ↓
terraform-policy-gate.yml
        ↓
CI BLOCK
        ↓
修复 / 正式豁免
```

这样文档、代码和流水线不会各写各的。

---

# 7. 标准生产变更证据链

每次生产变更应该能够找到：

```text
PR
 ↓
Commit SHA
 ↓
Terraform Plan
 ↓
Plan JSON
 ↓
Security Report
 ↓
Policy Report
 ↓
Approval
 ↓
Apply Log
 ↓
Verification
```

这条链路解决的是：**事故发生后不仅知道“改过”，还知道“谁、为什么、改了什么、谁批准、结果怎样”。**

---

# 8. 故障排查统一语言

所有 IaC 故障统一使用：

```text
现象
 ↓
判断 / 排查
 ↓
证据
 ↓
止损
 ↓
恢复
 ↓
验证
 ↓
长期治理
```

例如：

```text
Plan出现数据库Destroy
 ↓
停止Apply
 ↓
保存Plan JSON
 ↓
检查State Resource Address
 ↓
检查Terraform代码
 ↓
检查Provider
 ↓
检查Azure真实资源
 ↓
修复
 ↓
重新Plan
 ↓
确认无异常变化
 ↓
补Policy / 测试
```

---

# 9. 当前文档地图

| 文档 | 核心问题 | 类型 |
|---|---|---|
| `IaC-Governance-Production-Management.md` | 整体生产治理 | 总规范 |
| `IaC-模块封装资源隔离与生产管理学习手册.md` | 深入理解 IaC | 学习手册 |
| `IaC生产Ready验收报告.md` | 是否达到生产标准 | 验收 |
| `IaC管理规范.md` | 日常管理规则 | 基础规范 |
| `Terraform-Module治理规范.md` | Module 怎么设计 | 设计规范 |
| `Terraform-Backend实施规范.md` | State 怎么管理 | 实施规范 |
| `Terraform-Backend标准化规范.md` | Backend 怎么统一 | 标准规范 |
| `Terraform-代码扫描规范.md` | 代码怎么检查 | Quality/Security |
| `Terraform-Policy-Gate规范.md` | 什么变更必须阻断 | Policy |
| `IaC-CI验证流程规范.md` | CI 怎么串起来 | 流程规范 |
| `Resource保护策略与漂移检测规范.md` | 如何防删除 / 发现漂移 | 运行规范 |
| `Terraform-Azure-OIDC无密认证规范.md` | CI 用什么身份 | 身份规范 |
| `Azure资源命名与Tag管理规范.md` | 资源怎么命名和归属 | 资产规范 |
| `Azure资源未纳管Import清单模板.md` | 已有资源如何接管 | 资产模板 |

---

# 10. 最终目标

这个仓库最终应该让新人做到：

```text
打开 README
   ↓
知道仓库干什么
   ↓
打开 docs/README
   ↓
知道每个规范解决什么问题
   ↓
遇到问题可以按问题找文档
   ↓
文档能定位到 Terraform / Policy / Workflow
   ↓
Workflow 能产生证据
   ↓
证据能够支撑 Review / Approval / Audit
```

**最终不是“文档很多”，而是“每一个生产问题都有明确入口，每一条规范都有代码落点，每一次变更都有证据闭环”。**
