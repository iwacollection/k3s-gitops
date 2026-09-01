# IaC CI/CD 验证与生产变更流程规范

> **CI 不是“帮 Terraform 跑一下”，而是生产基础设施的自动化安全闸门。**

## 1. 总体流程

```text
Pull Request
 ↓
变更范围识别
 ↓
Terraform Format
 ↓
Terraform Validate
 ↓
Lint
 ↓
Security Scan
 ↓
Secret Scan
 ↓
Terraform Plan
 ↓
Plan JSON
 ↓
Policy Gate
 ↓
人工 Review
 ↓
Production Approval
 ↓
Apply
 ↓
Post-Apply Verification
 ↓
结果归档
```

---

# 2. 为什么要拆成多个 Gate

不要把所有检查塞进一个脚本。

```text
Quality Gate
= 代码能不能正确解析

Security Gate
= 有没有明显安全问题

Plan Gate
= 这次到底改变什么

Policy Gate
= 这次变化是否违反生产规则

Approval Gate
= 是否允许真正执行

Verification Gate
= 执行后是否达到目标
```

每层失败都应该告诉执行者：**哪里失败、为什么失败、如何修复。**

---

# 3. Pull Request 阶段

PR 必须包含：

- 变更原因
- 影响环境
- 影响资源
- 是否涉及网络
- 是否涉及身份权限
- 是否涉及数据资源
- 是否存在 destroy / replace
- 回滚方案
- 验证方案

推荐模板：

```text
变更目的：
影响环境：
影响资源：
风险等级：L1/L2/L3/L4
Destroy：是/否
Replace：是/否
安全影响：
回滚方式：
验证方式：
```

---

# 4. Quality Gate

必须执行：

```bash
terraform fmt -check -recursive
terraform validate
```

条件允许时执行：

```text
tflint
terraform test
module unit tests
```

失败：PR 不允许合并。

---

# 5. Security Gate

至少检查：

```text
Secret
RBAC
公网暴露
网络规则
加密
日志
数据库
Storage
Key Vault
```

高危结果必须阻断。

---

# 6. Plan Gate

Plan 是生产审批最重要的技术证据。

```bash
terraform plan -out=tfplan
terraform show -json tfplan > tfplan.json
```

Review 时不要只看：

```text
Plan succeeded
```

而要看：

```text
Create：多少
Update：多少
Delete：多少
Replace：多少
```

并明确关键资源列表。

---

# 7. Policy Gate

Policy Gate 对 Plan JSON 执行生产规则。

```text
tfplan.json
 ↓
OPA / Conftest
 ↓
Policy Rules
 ↓
PASS / BLOCK
```

例如：

```text
生产数据库 Delete
→ BLOCK

核心资源 Replace
→ BLOCK / 专项审批

生产 Storage 公网
→ BLOCK

Owner / Contributor 权限提升
→ BLOCK
```

详细规则以 `Terraform-Policy-Gate规范.md` 为准。

---

# 8. Approval Gate

Approval 的对象必须是**具体变更**。

审批人至少能够看到：

- Commit SHA
- PR
- Plan 摘要
- 风险等级
- Policy 结果
- 资源变化
- 验证方案
- 回滚方案

如果批准后 Commit 或 Plan 发生变化，必须重新审批。

---

# 9. Apply Gate

生产 Apply 不允许由开发者本地执行。

执行条件：

```text
Protected Branch
 AND
CI PASS
 AND
Policy PASS
 AND
Approval PASS
 AND
Plan 未发生变化
```

Apply 使用专用 Azure Identity，并限制 Scope。

---

# 10. Concurrency

同一个生产 State 不允许多个 Apply 同时进行。

```text
Production State
      ↓
Concurrency Lock
      ↓
Apply A ─────→ running
Apply B ─────→ waiting / blocked
```

目的：避免两个变更同时读取旧 State 并产生竞争。

---

# 11. Apply 后验证

Apply 成功后自动或人工验证：

```text
Terraform State
 ↓
Azure Resource
 ↓
Health Check
 ↓
业务关键路径
```

例如：

```text
AKS
→ Cluster Ready
→ Node Ready
→ API Ready

ACR
→ Login
→ Pull

Ingress
→ HTTPS
→ Endpoint

Database
→ Network
→ Connection
```

---

# 12. 失败处理

### Plan 失败

```text
停止
 ↓
读取错误
 ↓
修复代码 / Provider / State问题
 ↓
重新Plan
```

### Policy 失败

```text
停止
 ↓
确认规则
 ↓
修改变更
或进入正式豁免流程
```

### Apply 失败

不要立即重复 Apply。

先确认：

- Terraform State
- Azure 真实资源
- 已完成资源
- 未完成资源
- 部分成功的副作用

再决定继续、修复还是恢复。

---

# 13. CI 产物

推荐保存：

```text
terraform plan
terraform plan JSON
security scan report
policy report
apply log
verification result
```

注意：Plan / State 可能包含敏感信息，必须控制访问范围和保留周期。

---

# 14. Drift Detection

CI/CD 之外还需要定期检查：

```text
Scheduled Plan
 ↓
发现非预期变化
 ↓
告警
 ↓
确认来源
 ↓
代码修复或资源恢复
```

Drift Detection 不是自动 Apply。

**发现漂移与修复漂移必须分开。**

---

# 15. 最终验收

```text
PR → Quality
PR → Security
PR → Plan
PR → Policy
PR → Review
PR → Approval
PR → Apply
PR → Verify

Scheduled → Drift
```

最终目标是让 CI 从“构建工具”升级为**生产基础设施变更控制系统**。
