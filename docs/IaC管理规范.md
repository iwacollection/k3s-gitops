# IaC 管理规范

> **一句话：IaC 不是“把 Azure 写成 Terraform”，而是用代码、评审、策略、权限、状态、执行、验证和审计，把基础设施生命周期变成可控流程。**

## 1. 一眼看懂：生产 IaC 到底管什么

```text
业务需求
  ↓
资源设计
  ↓
Terraform 代码
  ↓
Pull Request
  ↓
代码质量 + 安全扫描
  ↓
Terraform Plan
  ↓
Policy Gate
  ↓
人工 Review
  ↓
生产 Approval
  ↓
受控 Apply
  ↓
Azure 实际资源
  ↓
健康验证
  ↓
State / 审计证据
  ↓
持续 Drift 检查
  └────────────→ 下一次变更
```

**核心原则：**任何关键阶段失败，都不能默认继续向下执行。

---

## 2. 管理对象与边界

### 2.1 本仓库负责

- Azure 基础设施
- Kubernetes / K3s 基础设施
- 网络与安全边界
- 计算、存储、数据库等基础资源
- 基础监控与平台能力
- Terraform Module
- Terraform Provider 与版本锁定
- Terraform State / Backend 配置
- Policy Gate 与 IaC 安全约束
- GitHub Actions 中的 IaC 生命周期

### 2.2 本仓库不负责

- 业务源代码
- 应用镜像构建
- 业务发布流水线
- 应用运行时业务配置
- 业务数据本身的日常修改

边界不清时，必须先明确 Ownership，再决定是否纳入本仓库。

---

## 3. 目录职责

```text
modules/
  ↓
  可复用基础设施能力

infrastructure/terraform/environments/
  ↓
  每个环境的实际资源组合与参数

policy/
  ↓
  哪些配置/Plan 绝对不允许进入生产

.github/workflows/
  ↓
  哪些检查必须通过、谁可以执行 Apply

docs/
  ↓
  规范、设计、Runbook、验收和故障处理
```

### 目录边界原则

| 内容 | 应该放哪里 | 不应该放哪里 |
|---|---|---|
| 通用资源封装 | Module | production 里复制粘贴 |
| 环境参数 | environment | Module 内硬编码 |
| 禁止规则 | policy | shell 脚本里偷偷判断 |
| CI Gate | workflow | 人工记忆 |
| 操作方法 | docs/Runbook | PR 评论里长期保存 |

---

## 4. Resource Ownership：每个生产资源必须有人负责

每个资源至少必须能回答：

```text
它是什么？
为什么存在？
属于哪个环境？
谁负责？
谁可以修改？
依赖谁？
如果删除会影响什么？
```

建议最低 Tag 契约：

```text
Environment
Owner
ManagedBy=Terraform
Purpose
CostCenter（如适用）
```

缺少 Owner 的生产资源不能作为“无人负责资源”长期存在。

---

## 5. 资源生命周期标准

```text
Discover
  ↓
Design
  ↓
Create
  ↓
Operate
  ↓
Modify / Scale
  ↓
Deprecate
  ↓
Delete
```

每一个阶段都必须有明确的进入条件和退出条件。

---

## 6. 我要新增资源

### 6.1 新增前

必须确认：

- 业务目的
- Owner
- Environment
- Resource Group
- 命名规则
- Tag
- 网络位置
- 身份与权限
- 数据敏感性
- 备份要求
- 监控要求
- 成本预估
- 与现有资源的依赖

### 6.2 执行流程

```text
需求
 ↓
资源设计
 ↓
选择已有 Module / 设计新 Module
 ↓
提交 PR
 ↓
fmt / validate / lint
 ↓
Security Scan
 ↓
Plan
 ↓
Policy Gate
 ↓
Review
 ↓
Production Approval
 ↓
Apply
 ↓
Azure 验证
 ↓
State 验证
 ↓
审计证据归档
```

### 6.3 完成标准

资源存在并不是完成。必须同时满足：

- 资源健康
- 网络符合预期
- 权限符合预期
- Tag 完整
- Monitoring 生效
- State 已记录
- Plan 无未解释变化
- 证据可追溯

---

## 7. 我要修改资源

修改前永远先看 Plan，而不是先猜 Terraform 会做什么。

```text
Create  → 为什么创建？
Update  → 改了什么？
Delete  → 为什么删除？
Replace → 为什么必须重建？
```

### 修改的四级风险

| 变化 | 风险 | 默认处理 |
|---|---|---|
| Metadata/Tag | 低 | 正常 Review |
| 普通属性 Update | 中 | Review + 验证 |
| 核心配置 Update | 高 | 业务影响评估 |
| Delete / Replace | 很高 | STOP + 专项确认 |

出现未预期 Delete / Replace，**不得以“Plan 看起来正常”为理由继续 Apply**。

---

## 8. 我要删除资源

删除前必须完成：

```text
资源确认
 ↓
Owner 确认
 ↓
依赖关系确认
 ↓
数据保留/备份确认
 ↓
业务影响确认
 ↓
Plan 确认 Delete
 ↓
Policy Gate
 ↓
Production Approval
 ↓
Apply
 ↓
依赖服务验证
 ↓
审计记录
```

### 不确定时的默认原则

> **不知道资源是什么 → 不删除。**

> **知道资源是什么但不知道是否还能删 → 不删除。**

---

## 9. 我要扩容

扩容不是看到 CPU 高就加机器。

首先判断：

```text
CPU
Memory
Disk IO
Network
Connection
Storage Capacity
Queue / Backlog
Application Limit
Database Limit
```

然后判断：

```text
资源不足？
还是应用/数据库/网络瓶颈？
```

再选择：

```text
纵向扩容
或
横向扩容
```

扩容完成必须验证：

- 容量
- 延迟
- 吞吐
- 错误率
- 告警
- 成本
- Auto Scaling 行为（如适用）

---

## 10. 我要接管已有 Azure 资源

```text
Azure 资源发现
 ↓
资源分类
 ↓
确认是否应纳管
 ↓
Import 清单登记
 ↓
Terraform Resource
 ↓
Import
 ↓
Plan
 ↓
解释所有差异
 ↓
补齐 Terraform 配置
 ↓
再次 Plan
 ↓
No unexpected Delete / Replace
 ↓
Review
 ↓
纳管完成
```

**Import 成功只代表 State 建立了资源地址，不代表治理完成。**

---

## 11. Module 修改治理

Module 是基础设施平台的“公共代码”，一个错误可能同时影响多个环境。

修改前必须评估：

```text
所有调用方
 ↓
变量默认值
 ↓
Resource 地址
 ↓
Resource Schema
 ↓
ForceNew
 ↓
Provider 行为
 ↓
依赖关系
 ↓
State Migration
 ↓
Plan 中的 Delete / Replace
```

### Module 修改的完成条件

- 调用方已识别
- 向后兼容性已评估
- 测试通过
- 关键环境 Plan 已检查
- 没有未解释 Replace/Delete
- 需要 State Migration 时已有迁移方案

---

## 12. Provider 升级治理

Provider 升级属于基础设施运行时变化，不是普通依赖升级。

```text
查看 Changelog
 ↓
识别 Breaking Change
 ↓
锁定目标版本
 ↓
更新 lock file
 ↓
init -upgrade
 ↓
validate
 ↓
Plan
 ↓
比较升级前后变化
 ↓
检查 Replace / Delete
 ↓
Review
 ↓
非生产验证
 ↓
生产 Approval
 ↓
Apply
 ↓
验证
```

禁止“升级 Provider + 大规模资源修改”混在一个不可解释的生产 PR 中。

---

## 13. Drift 管理

### 13.1 什么是 Drift

```text
Git / Terraform
     ↓
期望状态

Azure
     ↓
实际状态

期望状态 ≠ 实际状态
        ↓
       Drift
```

### 13.2 Drift 来源

- Portal 人工修改
- Azure CLI 修改
- 紧急生产操作
- Azure Policy 自动修正
- 其他 IaC 系统
- 平台自动化
- 未授权操作

### 13.3 Drift 处理

```text
发现 Drift
 ↓
确定来源
 ↓
判断变更是否合法
 ├── 合法且应长期存在
 │      ↓
 │   回写 Terraform
 │
 └── 非法/临时/错误
        ↓
     恢复 Terraform 期望状态
```

Portal 不应成为 Terraform 管理资源的长期修改入口。

---

## 14. 权限边界

```text
开发者
  ↓
修改代码 + PR

Reviewer
  ↓
检查设计与风险

CI
  ↓
OIDC + 最小权限

Production Approval
  ↓
授权生产 Apply

Azure
  ↓
真实资源
```

禁止：

- 长期 Azure Client Secret
- 共享管理员账号
- 开发者直接生产 Apply
- Workflow 允许任意分支 Apply
- 通过修改 Workflow 绕过 Policy

---

## 15. Policy 豁免治理

安全规则确实可能存在合理例外，但例外必须是**可审计的临时授权**。

每个豁免必须记录：

- Policy ID
- 资源
- 原因
- 风险
- Owner
- 审批人
- 创建时间
- 到期时间
- 替代控制措施

禁止永久 `skip policy`。

---

## 16. State 管理边界

State 是生产资产，必须遵守 Backend 规范。

```text
代码
 ↓
Plan
 ↓
State
 ↓
Azure
```

禁止：

- 手工编辑 State
- 未确认影响就 `state rm`
- 用删除 State 的方式解决 Terraform 错误
- 并发写同一 State

State 异常时必须进入 Runbook，而不是临时“修一下 JSON”。

---

## 17. 变更完成定义

生产变更只有同时满足以下条件才算完成：

```text
Plan 与预期一致
      +
Policy PASS
      +
Approval 完成
      +
Apply 成功
      +
Azure 健康
      +
业务健康
      +
State 正常
      +
无未解释 Drift
      +
证据完整
      ↓
Change Complete
```

---

## 18. 严禁事项

- 直接生产 `terraform apply`
- 绕过 PR / Review / Approval
- 关闭 Policy 换取 CI 通过
- 永久 Policy 豁免
- 手工编辑 State
- 未解释 Destroy / Replace 直接 Apply
- Portal 长期管理 Terraform 资源
- Import 后直接 Apply 未解释差异
- Provider 升级后不做 Plan
- Module 改动不检查调用方

---

## 19. 相关 Runbook

发生实际操作或故障时，不要只看本规范，应进入：

`docs/IaC-生产变更运行手册.md`

Runbook 覆盖：新增、修改、删除、扩容、Import、Module、Provider、Destroy、Replace、State Lock、State 异常、Drift、Apply 失败、部分成功、紧急变更和回滚。
