# IaC 文档中心

> **目标：不是让你“记住 Terraform 命令”，而是让你能解释生产 IaC 为什么这样设计、风险在哪里、出了问题怎么处理。**

---

## 一、先理解整个仓库

```text
Terraform Module
      ↓
Production Environment
      ↓
Terraform Plan
      ↓
Security Scan
      ↓
Policy Gate
      ↓
Approval
      ↓
Apply
      ↓
Azure / Kubernetes Verification
      ↓
Drift Detection
```

对应关系：

| 层 | 目录/文件 | 主要职责 |
|---|---|---|
| 环境 | `infrastructure/terraform/environments/production` | 定义生产到底使用什么 |
| 模块 | `infrastructure/terraform/modules` | 封装资源创建能力 |
| 策略 | `policy/terraform` | 定义什么变更禁止进入生产 |
| CI | `.github/workflows` | 定义检查、审批、执行边界 |
| 文档 | `docs` | 定义标准、原理、故障处理 |

---

# 二、推荐阅读路径

## 第一阶段：理解生产 IaC

### 1. `IaC-模块封装资源隔离与生产管理学习手册.md`

重点理解：

- Module 为什么要封装
- Environment 为什么要隔离
- Resource Group / Subscription 如何划分边界
- Terraform State 为什么是核心资产
- 什么情况下必须拆 State
- Import / Moved / State Migration 怎么避免误重建
- Plan / Approval / Concurrency / `prevent_destroy` 的作用
- Policy Gate 为什么必须存在

---

## 第二阶段：理解生产治理

### 2. `IaC-Governance-Production-Management.md`

重点理解：

```text
已有资源
   ↓
Terraform 接管
   ↓
State 管理
   ↓
CI/CD
   ↓
权限
   ↓
生产变更
   ↓
回滚
```

---

## 第三阶段：理解 Policy Gate

### 3. `Terraform-Policy-Gate规范.md`

这是当前重点治理文档。

先理解：

```text
代码正确
   ≠
安全
   ≠
允许生产
```

再理解：

```text
Checkov
   ↓
Terraform Plan
   ↓
OPA / Conftest
   ↓
Policy Gate
```

最后阅读：

```text
policy/terraform/terraform.rego
```

把每一条 `PGxxx` 规则与文档对起来。

---

# 三、Policy Gate 学习地图

```text
Policy Gate
│
├── PG001
│   └── 禁止生产资源删除
│
├── PG002
│   └── 禁止核心资源 Replace
│
├── PG003
│   └── 禁止 Owner RBAC
│
├── PG004
│   └── 禁止 Contributor RBAC
│
├── PG005
│   └── Storage 禁止公网访问
│
├── PG006
│   └── PostgreSQL 禁止公网访问
│
├── PG007
│   └── 生产 Tag 契约
│
├── PG008
│   └── NSG 高风险端口禁止公网开放
│
└── PG009
    └── Unknown Action 默认失败
```

学习每条规则时都问四个问题：

```text
1. 为什么危险？
2. Terraform Plan 怎么表现？
3. Policy 怎么识别？
4. 触发以后怎么处理？
```

---

# 四、治理规范目录

| 文档 | 用途 |
|---|---|
| `IaC-Governance-Production-Management.md` | 总体生产治理 |
| `IaC-模块封装资源隔离与生产管理学习手册.md` | 深入学习与复习 |
| `IaC-生产Ready验收报告.md` | 生产验收 |
| `IaC管理规范.md` | 基础管理规范 |
| `Terraform-Policy-Gate规范.md` | **策略即代码 / 风险阻断** |
| `Terraform-Module治理规范.md` | Module 生命周期与规范 |
| `Terraform-Backend实施规范.md` | State Backend 落地 |
| `Terraform-Backend标准化规范.md` | Backend 标准 |
| `Terraform-代码扫描规范.md` | 代码与安全扫描 |
| `Resource保护策略与漂移检测规范.md` | 防删除与 Drift |
| `Terraform-Azure-OIDC无密认证规范.md` | Azure 无密认证 |
| `Azure资源命名与Tag管理规范.md` | 资源治理与成本归属 |
| `Azure资源未纳管Import清单模板.md` | 已有资源接管 |
| `IaC-CI验证流程规范.md` | CI 检查流程 |

---

# 五、生产 IaC 的标准闭环

```text
┌──────────────────────┐
│ 1. 需求               │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│ 2. Terraform 修改     │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│ 3. Pull Request       │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│ 4. Quality Gate       │
│ fmt / validate / lint │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│ 5. Security Gate      │
│ Checkov               │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│ 6. Terraform Plan     │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│ 7. Policy Gate        │
│ OPA / Conftest         │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│ 8. 人工 Review         │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│ 9. Production Approval│
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│ 10. Terraform Apply   │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│ 11. Azure/K8s Verify  │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│ 12. Drift Detection   │
└──────────────────────┘
```

---

# 六、遇到生产事故怎么查

统一采用：

```text
现象
 ↓
判断 / 排查
 ↓
证据
 ↓
事故处理
 ↓
恢复验证
 ↓
长期治理
```

例如 Terraform 误判导致 AKS Replace：

```text
现象
→ Plan 出现 delete + create

判断
→ 是否 ForceNew？是否配置缺失？是否 State 错位？

证据
→ Plan JSON + State + Azure Resource ID

事故处理
→ 立即停止 Apply

恢复验证
→ 确认现有 AKS 未被破坏

长期治理
→ 增加 PG002 + Module 测试 + Review 规则
```

---

# 七、文档写作标准

所有新增治理文档必须尽量回答：

```text
是什么？
为什么？
解决什么生产问题？
怎么执行？
失败怎么办？
如何回滚？
如何验证？
规模扩大以后怎么演进？
```

不要只写：

```text
执行 terraform xxx
```

而要解释：

```text
为什么执行
 ↓
会改变什么
 ↓
可能产生什么风险
 ↓
如何验证
 ↓
失败如何恢复
```

---

# 八、当前仓库的核心治理原则

```text
Git
= 期望状态

Terraform State
= Terraform 与 Azure 资源的映射

Azure
= 真实状态

Plan
= 变更预测

Policy
= 自动风险控制

Approval
= 人工责任边界

Apply
= 受控执行

Verification
= 结果确认

Drift Detection
= 偏差发现
```

最终目标：

> **让生产基础设施变更从“有人会 Terraform”升级成“系统知道什么能改、什么不能改、谁批准、怎么执行、怎么验证、出了问题怎么恢复”。**
