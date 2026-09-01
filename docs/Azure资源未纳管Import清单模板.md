# Azure 资源未纳管 Import 清单模板

> **一眼看懂：先盘点真实资源，再决定谁纳管；Import 成功只是开始，Plan 校准通过才算完成。**

## 1. 标准流程

```text
Azure 真实资源
 ↓
资源盘点
 ↓
是否应该纳管？
 ├─ 否 → 记录例外 + Owner + 原因
 └─ 是
     ↓
Terraform Resource 定义
     ↓
Import
     ↓
Plan
     ↓
配置校准
     ↓
No unexpected changes
     ↓
Review / 合并
```

## 2. 单资源登记表

| 字段 | 内容 |
|---|---|
| Resource Name | |
| Resource Type | |
| Azure Resource ID | |
| Subscription | |
| Resource Group | |
| Environment | |
| Owner | |
| Purpose | |
| Terraform Module | |
| Terraform Address | |
| Import ID | |
| 数据/业务风险 | 低/中/高 |
| 是否允许 Replace | 是/否 |
| 是否允许 Delete | 是/否 |
| Import 负责人 | |
| Review 人 | |
| Import 时间 | |
| Plan 结果 | |
| 验证结果 | |

## 3. Import 前检查

- Resource ID 正确
- Subscription / Resource Group 正确
- Owner 明确
- 业务依赖明确
- 是否存在数据
- 是否允许 Terraform 接管
- Provider 支持该资源
- Module 边界明确

## 4. Plan 校准规则

```text
Update
 ↓
逐项解释差异

Replace
 ↓
STOP
 ↓
检查 ForceNew / 配置缺失 / Provider 差异

Delete
 ↓
STOP
 ↓
禁止直接 Apply
```

Import 后出现差异并不一定是错误，但**每个重要差异都必须有明确原因**。

## 5. 完成标准

只有同时满足以下条件才算“已纳管”：

- State 存在正确资源地址
- Plan 无未预期 Delete / Replace
- 关键属性与 Azure 实际状态一致
- Owner / Tag 完整
- 安全策略满足要求
- Import 记录完整
- Review 完成

## 6. 批量纳管顺序

```text
普通无状态资源
 ↓
网络
 ↓
安全
 ↓
计算
 ↓
数据库 / 存储
 ↓
AKS 核心资源
```

核心生产资源应单独 Import、单独 Plan、单独验证。

## 7. 禁止事项

- 重新创建已经存在的生产资源
- Import 后不做 Plan
- 为了消除差异而随意覆盖真实配置
- 未确认业务影响就 Replace
- 用 `terraform state rm` 伪装成完成纳管
- 未记录 Owner 的资源长期成为孤儿资源
