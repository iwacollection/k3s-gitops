# Resource 保护策略与 Drift 检测规范

> **核心原则：Terraform 可以自动化，但不能因为自动化而失去对删除、重建和人工漂移的控制。**

## 1. 一眼看懂

```text
Terraform Code
      ↓
Terraform Plan
      ↓
发现 Destroy / Replace
      ↓
风险判断
 ┌────┴─────────┐
低风险          高风险
 ↓               ↓
继续检查       Policy / Approval
                 ↓
              阻断或审批
```

另一条链路：

```text
Azure实际状态
      ↓
Scheduled Plan
      ↓
Drift Detection
      ↓
发现偏差
      ↓
判断是否授权
 ┌────┴────┐
是          否
↓           ↓
代码化      恢复期望状态
```

---

# 2. 资源分级

### 核心资源

- VNet / Subnet
- AKS
- Database
- Key Vault
- Identity / RBAC

默认：严格保护。

### 重要资源

- ACR
- Storage
- Monitoring

### 普通资源

低影响的辅助资源，可使用较低风险等级，但仍必须经过 CI。

---

# 3. prevent_destroy

核心资源可以使用：

```hcl
lifecycle {
  prevent_destroy = true
}
```

作用：在 Terraform 层形成最后一道资源删除保护。

但它不是唯一保护。

完整防线应该是：

```text
Code Review
 ↓
Plan
 ↓
Policy Gate
 ↓
Approval
 ↓
prevent_destroy
 ↓
Azure RBAC / Policy
```

---

# 4. 为什么 prevent_destroy 不能解决全部问题

它主要保护 Terraform 资源生命周期。

它不能自动解决：

- Azure Portal 人工删除
- Azure API 直接删除
- State 被错误修改
- Resource Address 错位
- Provider 导致 Replace
- 权限本身过大

所以必须结合身份、Policy、审计和 Drift Detection。

---

# 5. Drift 定义

三种状态必须区分：

```text
代码
State
Azure真实资源
```

正常：

```text
代码 ≈ State ≈ Azure
```

漂移：

```text
代码 / State
     ≠
Azure
```

State 本身异常则是另一类问题，不能简单叫 Drift。

---

# 6. Drift 检测

推荐定期执行只读检查：

```text
Scheduled Workflow
 ↓
Terraform Init
 ↓
Terraform Plan
 ↓
解析变化
 ↓
判断是否存在非预期 Drift
 ↓
产生告警 / Issue
```

**Drift Detection 默认只发现，不自动修复。**

原因：自动修复可能覆盖合法的紧急人工操作。

---

# 7. Drift 处理

发现漂移后首先问：

```text
是谁改的？
为什么改？
是否经过审批？
是否应该长期存在？
```

### 合法变更

```text
Azure变化
 ↓
确认业务意图
 ↓
回写 Terraform
 ↓
Plan
 ↓
合并
```

### 非法变更

```text
Azure变化
 ↓
确认不应存在
 ↓
制定恢复方案
 ↓
Plan
 ↓
Approval
 ↓
恢复
```

---

# 8. 出现 Replace 怎么办

```text
Plan
 ↓
-/+ replace
 ↓
停止 Apply
 ↓
识别 ForceNew 属性
 ↓
检查 Provider
 ↓
检查配置
 ↓
检查 State
 ↓
评估业务影响
```

核心资源 Replace 默认进入高风险流程。

---

# 9. 出现 Destroy 怎么办

```text
发现 destroy
 ↓
不要直接 Apply
 ↓
确认资源是不是应该删除
 ↓
确认 Resource Address
 ↓
确认 State
 ↓
确认代码 diff
 ↓
确认 Policy
 ↓
审批 / 修复
```

对于生产 Database、AKS、Network、Key Vault 等核心资源，默认阻断。

---

# 10. 紧急变更

紧急操作也不能变成“永久绕过 IaC”。

推荐：

```text
紧急人工变更
 ↓
记录原因
 ↓
恢复业务
 ↓
记录实际配置
 ↓
回写 Terraform
 ↓
重新 Plan
 ↓
纳入正式治理
```

目标是让人工操作成为短暂例外，而不是第二套长期配置系统。

---

# 11. 验收标准

资源保护体系必须同时具备：

```text
删除保护
Replace识别
Policy阻断
最小权限
Drift发现
人工确认
审计记录
恢复流程
```
