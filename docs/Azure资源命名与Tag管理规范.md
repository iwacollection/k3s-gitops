# Azure 资源命名与 Tag 治理规范

> **命名解决“这是什么”；Tag 解决“谁负责、属于什么、花了多少钱、是否应该被 Terraform 管理”。**

## 1. 一眼看懂

```text
Resource
 ├── Name → 人能快速识别
 └── Tags → 系统能分类、审计、计费、治理
```

资源创建不是“能创建就行”，必须同时满足身份、环境、Owner 和成本归属要求。

---

# 2. 命名模型

推荐：

```text
<环境>-<资源类型>-<地域>-<序号>
```

例如：

```text
prod-aks-eastasia-001
prod-vnet-eastasia-001
prod-acr-eastasia-001
```

如果 Azure 资源类型有自己的命名限制，以 Azure 规则为准，但必须保持整体语义一致。

---

# 3. 环境标准

| 环境 | 标识 | 用途 |
|---|---|---|
| 开发 | dev | 开发验证 |
| 测试 | test | 集成测试 |
| 预生产 | staging | 生产前验证 |
| 生产 | prod | 正式业务 |

禁止使用含义不清的：

```text
new
final
new2
backup-final
mytest
```

---

# 4. Tag 契约

Terraform 管理的资源应至少包含：

```text
Environment
ManagedBy
Owner
Application
CostCenter
```

建议进一步增加：

```text
DataClassification
Criticality
Service
Repository
Lifecycle
```

---

# 5. 每个 Tag 解决什么问题

| Tag | 解决的问题 |
|---|---|
| Environment | 属于哪个环境 |
| ManagedBy | 谁负责生命周期 |
| Owner | 谁对资源负责 |
| Application | 服务归属 |
| CostCenter | 成本归属 |
| Criticality | 业务重要程度 |
| Lifecycle | 临时还是长期 |

---

# 6. Tag 不能只是“写上去”

必须形成：

```text
定义
 ↓
Terraform Module默认注入
 ↓
CI检查
 ↓
Policy Gate
 ↓
Azure Policy兜底
```

不要依赖工程师每次手写 Tag。

---

# 7. Module 设计

推荐由平台层统一生成基础 Tag：

```text
Environment
ManagedBy
Owner
Application
CostCenter
```

Environment 可以提供业务特定 Tag，但不应该允许随意覆盖平台强制字段。

---

# 8. Tag 变更

Tag 通常属于低风险变更，但不能因为“只是 Tag”就完全绕过 CI。

原因：Tag 可能被用于：

- 成本统计
- 自动备份
- 自动清理
- 安全策略
- CMDB 同步
- 资源权限边界

---

# 9. 新资源验收

创建资源后检查：

```text
名称正确
 ↓
Environment正确
 ↓
ManagedBy正确
 ↓
Owner存在
 ↓
Application存在
 ↓
CostCenter存在
```

任何生产资源缺少关键 Tag 都应该被视为治理问题。

---

# 10. 命名迁移

修改资源名称可能导致 Terraform / Azure 认为资源发生变化。

因此名称变更必须检查：

- Azure 是否支持原地修改
- Terraform 是否产生 Replace
- Resource ID 是否改变
- 是否需要 State migration

不要为了“命名更漂亮”直接重建生产资源。

---

# 11. 验收标准

```text
名称可识别
环境可识别
Owner可追踪
成本可归属
管理方式可识别
关键Tag自动生成
CI自动检查
Policy可以阻断
```

**命名和 Tag 最终服务的是资产治理，而不是格式好看。**
