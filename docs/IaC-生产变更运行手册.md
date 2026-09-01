# IaC 生产变更运行手册（Runbook）

> **核心原则：先判断，再操作；先止损，再恢复；所有生产变更都必须有证据。**

## 0. 总体决策树

```text
发生变更/故障
 ↓
是否影响生产？
 ├─ 否 → 正常 PR 流程
 └─ 是
     ↓
是否存在 Delete / Replace / 数据风险？
 ├─ 是 → STOP + 风险评估 + Approval
 └─ 否 → 正常变更流程
```

## 1. 我要新增资源

```text
需求
 ↓
确认 Owner / 成本 / 网络 / 安全 / 依赖
 ↓
选择或新增 Module
 ↓
PR
 ↓
CI + Security + Policy
 ↓
Plan
 ↓
Review / Approval
 ↓
Apply
 ↓
Azure 健康验证
```

检查：命名、Tag、RBAC、网络边界、备份、监控、成本。

## 2. 我要修改资源

1. 修改 Terraform。
2. 执行 Plan。
3. 区分 Create / Update / Delete / Replace。
4. 对所有高风险变化确认影响。
5. Policy Gate。
6. Review / Approval。
7. Apply。
8. 验证业务与资源健康。

## 3. 我要删除资源

**删除是高风险操作。**

```text
删除请求
 ↓
确认 Owner / 业务依赖
 ↓
确认数据备份与保留期限
 ↓
Plan 确认 Delete
 ↓
Policy Gate
 ↓
人工 Approval
 ↓
Apply
 ↓
验证依赖服务
```

不确定资源用途时：**不要删除。**

## 4. 我要扩容

先确认瓶颈：

```text
CPU / Memory / IO / Network / Connection / Storage
```

再决定：

```text
纵向扩容
或
横向扩容
```

扩容后验证容量、性能、成本和告警。

## 5. 我要接管已有 Azure 资源

```text
盘点
 ↓
登记 Import 清单
 ↓
Terraform Resource
 ↓
Import
 ↓
Plan
 ↓
校准
 ↓
No unexpected Delete / Replace
 ↓
Review
```

Import 后禁止直接 Apply 未解释的差异。

## 6. 我要修改 Module

修改前检查所有调用方，并重点关注：

- Resource 地址
- 默认值
- Provider Schema
- ForceNew
- 依赖关系
- State Migration
- Delete / Replace

修改后必须运行完整 Plan。

## 7. 我要升级 Provider

```text
查看版本变更
 ↓
锁定目标版本
 ↓
init -upgrade
 ↓
validate
 ↓
Plan
 ↓
检查 schema / Replace / Delete
 ↓
Review
 ↓
Apply
 ↓
验证
```

## 8. Plan 出现 Destroy

**第一原则：不要 Apply。**

排查顺序：

1. 为什么 Terraform 认为资源应该删除？
2. Resource 地址是否变化？
3. State 是否正确？
4. 配置是否删除/改名？
5. Provider 是否改变行为？
6. 是否发生 Import/Move 问题？

```text
原因不明 → STOP
原因明确且删除经过批准 → 才能继续
```

## 9. Plan 出现 Replace

Replace 表示通常需要销毁并重新创建资源。

重点检查：

```text
ForceNew
配置变化
Provider schema
Resource ID
依赖资源
数据风险
停机风险
```

核心生产资源出现未预期 Replace：**BLOCK**。

## 10. State 锁住了

```text
发现 Lock
 ↓
检查是否有正在执行的 Apply
 ↓
有 → 等待
无 → 检查是否为异常残留
 ↓
记录 Lock 信息
 ↓
确认无人写 State
 ↓
受控解锁
 ↓
重新 Plan
```

禁止为了赶进度直接 `force-unlock`。

## 11. State 异常/损坏

```text
异常
 ↓
STOP Apply
 ↓
保存日志 / Plan / State版本
 ↓
确认 Backend 历史
 ↓
必要时恢复
 ↓
重新 Plan
 ↓
确认无异常 Destroy / Replace
```

禁止手工编辑 State JSON。

## 12. Drift：Portal 或其他系统改了资源

```text
Git 期望状态
      ≠
Azure 实际状态
```

先判断来源：

- 紧急人工变更
- Azure Policy / 平台自动修改
- 其他 IaC 系统
- 未授权人工修改

如果变更应该保留：回写 Terraform；否则恢复 Terraform 期望状态。

## 13. Apply 失败

**不要盲目重试。**

```text
失败
 ↓
保存错误日志
 ↓
确认 Terraform 是否已创建/修改部分资源
 ↓
检查 State
 ↓
检查 Azure 实际状态
 ↓
重新 Plan
 ↓
判断继续 / 修复 / 回滚
```

## 14. Apply 部分成功

这是最危险的状态之一，因为：

```text
Apply ≠ 全部成功
```

必须建立真实状态：

```text
Terraform State
       +
Azure Resource
       +
Apply Log
```

确认哪些资源成功、哪些失败、State 是否已记录，再决定下一步。

## 15. 生产紧急变更

紧急不等于绕过治理。

```text
事故
 ↓
止损
 ↓
明确变更目标
 ↓
最小范围修改
 ↓
紧急 Approval
 ↓
执行
 ↓
立即验证
 ↓
事故结束后补齐 Terraform / PR / 审计
```

紧急变更完成后必须回到正常 IaC 管理状态。

## 16. 如何回滚

先区分两种回滚：

### 配置回滚

```text
Git revert
 ↓
Plan
 ↓
Policy
 ↓
Approval
 ↓
Apply
 ↓
验证
```

### State / 资源恢复

不能简单理解为“恢复 Git 就一定恢复生产”。如果资源已经发生破坏，需要根据资源类型使用备份、快照或平台恢复能力。

```text
确认损坏范围
 ↓
保护现状
 ↓
选择恢复点
 ↓
恢复资源/数据
 ↓
校准 Terraform State
 ↓
Plan
 ↓
验证
```

## 17. 每次变更的结束检查

```text
[ ] Plan 与预期一致
[ ] Policy PASS
[ ] Approval 完成
[ ] Apply 成功
[ ] Azure 健康
[ ] 业务健康
[ ] State 正常
[ ] 无未解释 Drift
[ ] 日志已保存
[ ] 必要文档已更新
```

> **Runbook 的最终目标不是“把命令跑成功”，而是让生产变更可预测、可验证、可恢复、可审计。**
