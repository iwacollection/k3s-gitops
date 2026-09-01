# Azure 资源未纳管 Import 清单模板

> **一句话：先发现真实资源，再判断是否应该纳管；Import 只是建立 State 关系，Plan 校准无未解释高风险变化后才算真正纳管。**

## 1. 为什么需要 Import 清单

Azure 环境经常存在：

- Portal 创建资源
- 历史人工创建资源
- 其他 Terraform 仓库管理的资源
- ARM / Bicep 管理的资源
- 平台自动创建资源
- 临时资源
- 无 Owner 的遗留资源

不能看到“Azure 有资源”就直接 Import，也不能看到“Terraform 没有”就直接创建。

---

## 2. 一眼看懂：纳管决策树

```text
发现 Azure Resource
        ↓
确认 Resource ID
        ↓
是否已经被其他 IaC 管理？
 ├─ 是 → 不得重复纳管，确认 Ownership
 └─ 否
      ↓
是否应该长期存在？
 ├─ 否 → 删除/临时资源治理
 └─ 是
      ↓
Owner 是否明确？
 ├─ 否 → 进入待确认队列
 └─ 是
      ↓
是否允许 Terraform 管理？
 ├─ 否 → 记录例外
 └─ 是
      ↓
Import
      ↓
Plan
      ↓
配置校准
      ↓
无未解释 Delete / Replace
      ↓
Review
      ↓
正式纳管
```

---

## 3. 资源分类

| 分类 | 含义 | 默认处理 |
|---|---|---|
| P0 | 核心生产资源 | 单独评估、Import、验证 |
| P1 | 重要业务资源 | 优先纳管 |
| P2 | 普通生产资源 | 批量纳管 |
| P3 | 临时/低价值资源 | 确认是否应该保留 |
| EXCEPTION | 不纳管资源 | 必须记录原因和 Owner |

### P0 示例

- 核心网络
- 生产数据库
- 核心 Kubernetes / AKS 资源
- 身份与权限核心资源
- 核心存储

P0 资源不允许为了提高 Import 数量而批量操作。

---

## 4. 单资源登记模板

| 字段 | 内容 |
|---|---|
| Resource Name | |
| Resource Type | |
| Azure Resource ID | |
| Subscription | |
| Resource Group | |
| Environment | |
| Criticality | P0/P1/P2/P3 |
| Owner | |
| Purpose | |
| Current Management | Portal/Terraform/Bicep/ARM/Other |
| Existing IaC Repository | |
| Terraform Module | |
| Terraform Address | |
| Import ID | |
| 数据类型 | |
| 数据风险 | 低/中/高 |
| 是否允许 Replace | 是/否 |
| 是否允许 Delete | 是/否 |
| Backup | |
| Dependency | |
| Import 负责人 | |
| Reviewer | |
| Import 时间 | |
| Import 结果 | |
| First Plan 结果 | |
| Final Plan 结果 | |
| 验证结果 | |
| 纳管状态 | 待处理/Import中/校准中/完成/例外 |
| 备注 | |

---

## 5. Import 前检查

### 身份确认

- Azure Resource ID 正确
- Subscription 正确
- Resource Group 正确
- Environment 正确
- Resource Type 正确

### Ownership

- Owner 明确
- Purpose 明确
- 是否已有其他团队负责
- 是否已有其他 IaC 系统管理

### 业务风险

- 是否承载生产流量
- 是否保存业务数据
- 是否存在不可逆操作
- 是否有备份
- 是否存在强依赖

### Terraform 能力

- Provider 支持该资源
- Resource 类型正确
- Module 边界明确
- Provider 版本明确
- Import 能力符合当前 Provider 行为

---

## 6. Import 标准流程

```text
登记清单
 ↓
代码定义 Resource
 ↓
Review Resource 地址
 ↓
执行 Import
 ↓
确认 State 中存在资源
 ↓
执行 Plan
 ↓
逐项分析差异
 ↓
补齐 Terraform 配置
 ↓
再次 Plan
 ↓
确认无未解释 Delete / Replace
 ↓
安全检查 / Policy
 ↓
Review
 ↓
纳管完成
```

---

## 7. Import 后 Plan 差异处理

### Update

逐项解释：

```text
为什么 Terraform 与 Azure 不一致？
这个差异应该保留吗？
写入 Terraform 后是否仍然存在？
```

### Replace

```text
发现 Replace
 ↓
STOP
 ↓
检查 Resource ID
 ↓
检查配置缺失
 ↓
检查 ForceNew
 ↓
检查 Provider
 ↓
检查 Module
 ↓
确认数据/停机风险
```

没有明确批准前不得 Apply。

### Delete

Import 后出现 Delete 是严重信号，应优先排查：

- Import ID 错误
- Resource Address 错误
- Resource 配置不完整
- State 不正确
- Provider 差异
- 资源实际状态与预期不一致

**禁止为了消除 Delete 直接 Apply。**

---

## 8. 完成定义

资源只有同时满足以下条件才算“已纳管”：

```text
State 有正确 Resource Address
        +
Azure Resource ID 正确
        +
Owner 明确
        +
Tag 符合规范
        +
Security 符合规范
        +
Plan 无未解释 Delete / Replace
        +
关键差异已回写代码
        +
Review 完成
        +
验证完成
        ↓
Managed
```

---

## 9. 例外资源

确实不能纳管的资源不能简单忽略。

必须记录：

- Resource ID
- Owner
- 为什么不能纳管
- 当前由谁管理
- 当前安全控制
- 风险
- 下一次复审日期

```text
EXCEPTION
 ↓
Owner
 ↓
Reason
 ↓
Risk
 ↓
Compensating Control
 ↓
Review Date
```

没有 Owner 的 Exception 不允许无限期存在。

---

## 10. 批量纳管策略

不要一次 Import 全部生产资源。

推荐：

```text
低风险、无状态资源
 ↓
普通基础资源
 ↓
网络
 ↓
安全
 ↓
计算
 ↓
存储
 ↓
数据库
 ↓
Kubernetes 核心资源
```

P0 资源必须单独操作和验证。

---

## 11. Import 禁止事项

- 重新创建已有生产资源
- Import 后不执行 Plan
- 未解释差异直接 Apply
- 为消除差异随意覆盖 Azure 真实配置
- 用 `terraform state rm` 代替正确纳管
- 同一资源同时由两个 IaC 系统管理
- 未确认 Owner 就长期纳管
- 把 Exception 当成永久垃圾桶

---

## 12. 纳管验收记录

```text
资源：
Import 时间：
Commit SHA：
Import 结果：
First Plan：
差异数量：
Delete：0 / 已解释
Replace：0 / 已解释
最终 Plan：
Policy：PASS / FAIL
Review：
Azure 验证：
State 验证：
最终状态：完成 / 例外
```

> **Import 的终点不是“State 里有这个资源”，而是 Terraform 能稳定描述、验证和持续管理这个资源。**
