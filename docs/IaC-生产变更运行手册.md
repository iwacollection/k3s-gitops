# IaC 生产变更运行手册（Runbook）

> **目标：遇到生产 IaC 变更或故障时，不靠经验猜，而是按照“现象 → 判断 → 止损 → 证据 → 操作 → 验证 → 回滚 → 复盘”执行。**

## 0. 使用规则

### 0.1 四条铁律

1. **先看 Plan，再决定是否 Apply。**
2. **Delete / Replace / State 异常原因不明时，立即 STOP。**
3. **故障时先保护现状，再修复。**
4. **操作完成必须有验证证据。**

### 0.2 任何故障先做这 5 件事

```text
停止高风险操作
 ↓
保存 CI / Terraform 日志
 ↓
记录 Commit / Workflow / 环境
 ↓
确认 Terraform State 状态
 ↓
确认 Azure 实际状态
```

---

# 1. 我要新增资源

## 1.1 适用场景

业务需要新增 Resource Group、网络、计算、数据库、存储、AKS/K3s 或其他基础设施。

## 1.2 操作流程

```text
需求
 ↓
确认 Owner / Purpose / Environment
 ↓
确认网络、安全、权限、备份、监控、成本
 ↓
选择已有 Module
 ├─ 能满足 → 使用
 └─ 不能满足 → 设计新 Module
 ↓
PR
 ↓
fmt / validate / lint / Security Scan
 ↓
Plan
 ↓
检查 Create / Update / Delete / Replace
 ↓
Policy Gate
 ↓
Review
 ↓
Production Approval
 ↓
Apply
 ↓
资源验证
 ↓
State 验证
 ↓
审计证据
```

## 1.3 Apply 前检查

- Resource Name 正确
- Resource Group 正确
- Subscription 正确
- Environment 正确
- Owner / Tag 完整
- 网络边界正确
- RBAC 符合最小权限
- 公网入口符合策略
- 数据资源具备备份要求
- 监控和告警已规划
- 成本符合预期
- Plan 没有未解释 Delete / Replace

## 1.4 完成标准

资源创建成功只是第一步；必须同时验证 Azure 状态、关键配置、健康指标、Terraform State 和 CI 结果。

---

# 2. 我要修改资源

## 2.1 标准流程

```text
修改 Terraform
 ↓
Plan
 ↓
按 Action 分类
 ├─ Create
 ├─ Update
 ├─ Delete
 └─ Replace
 ↓
解释每个变化
 ↓
风险评估
 ↓
Policy / Review / Approval
 ↓
Apply
 ↓
验证
```

## 2.2 判断规则

| Plan Action | 默认处理 |
|---|---|
| Create | 确认是否为预期新增 |
| Update | 确认业务影响 |
| Delete | STOP，确认删除原因 |
| Replace | STOP，评估停机和数据风险 |

**任何未预期变化都必须先解释。**

---

# 3. 我要删除资源

## 3.1 删除前必须确认

```text
资源身份
 ↓
Owner
 ↓
业务依赖
 ↓
数据是否存在
 ↓
备份 / 保留期限
 ↓
DNS / 网络 / RBAC / 监控依赖
 ↓
业务影响
 ↓
回滚/恢复方案
```

## 3.2 删除执行

```text
Plan 确认 Delete
 ↓
Policy Gate
 ↓
业务/Owner 确认
 ↓
Production Approval
 ↓
Apply
 ↓
验证依赖服务
```

## 3.3 STOP 条件

- 不知道资源用途
- Owner 无法确认
- 依赖关系不清
- 数据备份不明确
- Delete 不是本次变更目标
- Policy Gate 未通过

> **不确定就不删除。**

---

# 4. 我要扩容

## 4.1 先判断瓶颈

```text
CPU
Memory
Disk IO
Network
Connection
Storage
Queue
Database
Application Limit
```

不要因为“CPU 高”就默认增加节点；先确认瓶颈在哪里。

## 4.2 决策

```text
容量不足
 ↓
纵向扩容？横向扩容？
 ↓
是否需要停机？
 ↓
成本是否可接受？
 ↓
Plan
 ↓
Apply
 ↓
容量/性能/业务验证
```

## 4.3 扩容后必须验证

- CPU / Memory 是否恢复
- 延迟是否改善
- 吞吐是否提升
- 错误率是否下降
- 告警是否恢复
- 成本是否符合预期
- Auto Scaling 是否正常（如适用）

---

# 5. 我要接管已有 Azure 资源（Import）

## 5.1 原则

**Import ≠ 纳管完成。**

Import 只是把 Azure Resource 建立到 Terraform State 的资源地址；真正完成纳管必须经过配置校准。

## 5.2 流程

```text
Azure 资源发现
 ↓
分类：纳管 / 例外 / 待确认
 ↓
Import 清单登记
 ↓
编写 Terraform Resource / Module
 ↓
Import
 ↓
Plan
 ↓
逐项解释差异
 ↓
补齐 Terraform 配置
 ↓
再次 Plan
 ↓
No unexpected Delete / Replace
 ↓
Review
 ↓
正式纳管
```

## 5.3 Import 后出现 Delete

立即 STOP。重点检查：

- Resource ID
- Terraform Address
- Module
- State
- 配置是否缺失
- Provider Schema

禁止为了“让 Plan 变绿”直接 Apply。

---

# 6. 我要修改 Module

## 6.1 为什么风险高

Module 是共享基础设施代码，一个错误可能同时影响多个环境和多个调用方。

## 6.2 修改前检查

```text
查找所有调用方
 ↓
检查变量和默认值
 ↓
检查 Resource 地址
 ↓
检查 Provider Schema
 ↓
检查 ForceNew
 ↓
检查依赖
 ↓
检查 State Migration
 ↓
Plan 所有关键环境
```

## 6.3 高风险变化

- Resource 地址改变
- Resource Type 改变
- ForceNew 属性改变
- 默认值改变
- Provider 版本变化
- Module 输出改变
- 依赖关系改变

出现未预期 Replace / Delete：**BLOCK**。

---

# 7. 我要升级 Provider

```text
阅读 Changelog
 ↓
确认 Breaking Change
 ↓
选择目标版本
 ↓
更新版本约束 / Lock File
 ↓
terraform init -upgrade
 ↓
validate
 ↓
Plan
 ↓
比较升级前后变化
 ↓
检查 Delete / Replace
 ↓
非生产验证
 ↓
Review / Approval
 ↓
生产 Apply
 ↓
验证
```

Provider 升级最好与普通业务资源变更拆开，避免一次 PR 同时引入大量不可解释变化。

---

# 8. Plan 出现 Destroy

> **默认动作：STOP。**

## 8.1 排查顺序

```text
为什么要删除？
 ↓
Terraform 配置是否删除？
 ↓
Resource 地址是否变化？
 ↓
是否需要 moved / State Migration？
 ↓
State 是否正确？
 ↓
Provider 是否改变行为？
 ↓
Import 是否正确？
 ↓
依赖资源是否变化？
```

## 8.2 判断

```text
原因不明 → BLOCK

原因明确但没有业务批准 → BLOCK

原因明确 + 风险确认 + Approval
→ 才允许继续
```

---

# 9. Plan 出现 Replace

Replace 通常意味着旧资源被销毁并重新创建，可能造成：

- 资源 ID 改变
- IP / DNS 改变
- 数据丢失
- 停机
- 依赖断裂
- Secret / Identity 变化

## 9.1 必查项

- ForceNew
- Resource ID
- Provider Schema
- 配置差异
- Module 变化
- Provider 升级
- 依赖关系
- 数据风险
- 停机风险

核心生产资源出现未预期 Replace：**立即 BLOCK**。

---

# 10. State 锁住了

## 10.1 默认原则

**不要看到 Locked 就直接 force-unlock。**

## 10.2 处理流程

```text
发现 Lock
 ↓
检查 GitHub Actions
 ↓
检查是否有人正在执行 Terraform
 ↓
记录 Lock ID / 持有者 / 时间
 ↓
确认没有 Terraform 正在写 State
 ↓
判断是否异常残留
 ├─ 否 → 等待
 └─ 是 → 受控解锁
 ↓
重新 Plan
 ↓
检查是否出现异常变化
```

## 10.3 禁止

- 为赶时间直接解锁
- 多个 Apply 并行写同一 State
- 解锁后直接 Apply，不重新 Plan

---

# 11. State 异常 / 损坏

## 11.1 典型现象

- State 无法读取
- Resource 地址消失
- State 与 Azure 明显不一致
- 大量资源突然 Destroy
- 大量资源突然 Replace
- Backend 恢复异常

## 11.2 处理

```text
异常
 ↓
STOP Apply
 ↓
保存 CI / Terraform 日志
 ↓
记录 Commit / State 版本
 ↓
确认 Azure 实际状态
 ↓
检查 Backend 历史版本
 ↓
选择恢复点
 ↓
恢复 / 修复
 ↓
重新 Plan
 ↓
确认无异常 Destroy / Replace
 ↓
恢复流水线
```

**禁止手工修改 State JSON。**

---

# 12. Drift：Portal 或其他系统修改了资源

## 12.1 判断模型

```text
Git / Terraform
      ↓
期望状态

Azure
      ↓
实际状态

期望 ≠ 实际
      ↓
Drift
```

## 12.2 先判断来源

- 紧急人工变更
- Portal / CLI
- Azure Policy
- 平台自动化
- 其他 IaC
- 未授权人工修改

## 12.3 处理分支

```text
Drift
 ↓
是否合法？
 ├─ 是、且应长期存在
 │     ↓
 │  回写 Terraform
 │
 └─ 否 / 临时变更
       ↓
   恢复 Terraform 期望状态
```

不要通过 `terraform import` 随意“掩盖 Drift”。先判断谁应该是事实来源。

---

# 13. Apply 失败

## 13.1 不要做什么

不要连续点击 Retry，也不要在不知道资源实际状态的情况下再次 Apply。

## 13.2 标准流程

```text
Apply 失败
 ↓
保存完整错误日志
 ↓
确认失败资源
 ↓
检查 Terraform State
 ↓
检查 Azure 实际资源
 ↓
判断是否部分成功
 ↓
重新 Plan
 ↓
确定根因
 ├─ 配置错误 → 修复 PR
 ├─ 权限错误 → 修复权限
 ├─ 配额错误 → 处理容量
 ├─ Azure 服务异常 → 等待/升级
 └─ State 异常 → State Runbook
 ↓
重新验证
```

---

# 14. Apply 部分成功

这是高风险状态：**Apply 失败不代表 Azure 什么都没发生。**

必须同时检查：

```text
Apply Log
   +
Terraform State
   +
Azure 实际资源
```

## 14.1 判断矩阵

| 情况 | 下一步 |
|---|---|
| Azure 没创建，State 也没有 | 修复后重新 Plan |
| Azure 已创建，State 已记录 | 重新 Plan，继续收敛 |
| Azure 已创建，State 未记录 | STOP，确认 Import / State 恢复策略 |
| 部分资源成功 | 逐资源确认状态后再决定 |
| 出现异常 Replace/Delete | STOP |

禁止假设“Terraform 会自动知道刚才发生了什么”。必须用 State + Azure 实际状态确认。

---

# 15. 生产紧急变更

> **紧急变更的目标是缩短响应时间，不是取消安全边界。**

## 15.1 流程

```text
事故
 ↓
止损
 ↓
明确变更目标
 ↓
确定最小变更范围
 ↓
紧急 Approval
 ↓
执行
 ↓
立即验证
 ↓
恢复业务
 ↓
补齐 Terraform / PR / 审计
 ↓
消除 Drift
```

## 15.2 紧急变更必须记录

- 事故编号
- 变更原因
- 操作人
- Approval 人
- 时间
- 目标资源
- 修改内容
- 风险
- 验证结果
- 后续 Terraform 收敛计划

---

# 16. 如何回滚

## 16.1 配置回滚

```text
确认上一稳定版本
 ↓
Git Revert
 ↓
Plan
 ↓
Policy Gate
 ↓
Approval
 ↓
Apply
 ↓
验证
```

## 16.2 资源恢复

Git Revert **不等于** Azure 已经恢复。

如果资源已经被删除、Replace 或数据被破坏，需要根据资源类型使用：

- Azure Backup
- Snapshot
- 数据库备份 / PITR
- 平台恢复能力
- 重新创建 + 数据恢复

具体恢复方式必须由资源类型决定。

## 16.3 回滚后的 Terraform 校准

```text
恢复资源
 ↓
确认 Azure 实际状态
 ↓
确认 State
 ↓
必要时 Import / State Migration
 ↓
Plan
 ↓
No unexpected Delete / Replace
 ↓
业务验证
```

---

# 17. 变更结束检查清单

```text
[ ] Plan 与预期一致
[ ] Policy Gate PASS
[ ] Review 完成
[ ] Approval 完成
[ ] Apply 成功
[ ] Azure 资源健康
[ ] 业务健康
[ ] State 正常
[ ] 无未解释 Drift
[ ] 监控 / 告警正常
[ ] 成本变化符合预期
[ ] CI 日志已保存
[ ] 变更证据可追溯
[ ] 必要文档已更新
```

# 18. 故障升级条件

出现以下情况不要继续自行尝试：

- 核心生产资源出现未预期 Destroy
- 核心生产资源出现未预期 Replace
- State 无法确认真实性
- State 恢复后资源地址异常
- Apply 部分成功且无法确定实际状态
- 数据可能丢失
- 网络核心组件可能中断
- IAM / RBAC 可能失控
- Policy Gate 被绕过

应立即进入事故处理流程，并保留现场证据。

# 19. 最终原则

```text
Terraform 的目标不是“命令执行成功”

而是：

期望状态明确
      ↓
变更风险可见
      ↓
违规变更可阻断
      ↓
生产操作可审批
      ↓
执行结果可验证
      ↓
失败可以恢复
      ↓
全过程可以审计
```
