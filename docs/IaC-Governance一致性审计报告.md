# IaC Governance 一致性审计报告

> **审计目标：不是检查“有没有文档”，而是验证“文档说的规则是否真的被 Workflow、Policy、GitHub 保护和 Azure 权限执行”。**
>
> 本报告是本仓库治理体系的控制面审计入口。以后每次修改生产治理规则，都必须同步更新这里的控制矩阵和证据。

---

# 1. 一眼看懂

生产 IaC 治理必须形成下面的闭环：

```text
治理规范
   ↓
Policy ID / 控制编号
   ↓
Terraform / Rego / Workflow
   ↓
GitHub PR / Ruleset / Environment
   ↓
Azure OIDC / RBAC
   ↓
真实 Plan / Apply
   ↓
Post-Apply Verification
   ↓
Evidence
```

如果其中任何一层只有“文档描述”而没有执行证据，就不能称为 Production Ready。

---

# 2. 审计结论

本次审计发现：

| 控制面 | 当前状态 | 结论 |
|---|---|---|
| Terraform Policy Rego | 已存在 | PASS |
| Policy Gate PR 回归测试 | 已补齐 | PASS |
| PG001-PG009 规则可执行性 | 已增加负向测试 | PASS |
| Checkov / Terraform Quality | 已接入 PR | PASS |
| 生产实际 Plan 执行 Rego | **尚未完全闭环** | **P0 GAP** |
| GitHub Ruleset | API 当前返回空集合 | **P0 GAP** |
| CODEOWNERS | 已存在 | PARTIAL |
| Production Environment Approval | Workflow 使用 Environment | PARTIAL，必须确认仓库侧保护规则 |
| Azure OIDC | Apply 使用 OIDC | PASS |
| Azure RBAC | Terraform 显式管理部分 RBAC | PASS / NEED INVENTORY |
| Azure 权限最小化 | Apply / Quota 身份分离 | PASS / NEED LIVE VERIFICATION |
| Apply 后 Azure 验证 | 已存在大量验证 | PASS |
| 文档与代码映射 | 已建立基础 | NEED CONTINUOUS AUDIT |

## 最重要的两个 P0

### P0-1：GitHub Ruleset 当前没有发现

仓库 Rulesets API 当前返回：

```text
[]
```

因此不能把 CODEOWNERS 或 workflow 文件描述当成“main 分支不可绕过”的证明。

必须在 GitHub 仓库侧配置并验证：

```text
main
 ├── 禁止直接 push
 ├── 必须 Pull Request
 ├── 必须通过 required status checks
 ├── 必须完成 required review
 ├── CODEOWNERS review 生效
 ├── conversation resolution
 └── 管理员绕过策略明确
```

> 如果 GitHub 账号/组织权限允许配置 Ruleset，应把它作为仓库 Production Ready 的阻断项；如果当前连接器无法写入 Ruleset，则必须由仓库管理员在 GitHub UI/API 完成并把规则 ID、截图或 API 导出作为证据保存。

### P0-2：Rego 已存在，但生产 Apply 前没有证据证明实际 `apply.tfplan` 一定经过 Conftest

当前 Rego 已经定义 PG001-PG009，PR Policy Gate 也已经加入确定性的负向回归测试。

但 PR 回归测试使用的是：

```text
固定 JSON Fixture
```

而不是：

```text
真实 Azure Remote State
       ↓
terraform plan
       ↓
apply.tfplan
       ↓
terraform show -json
       ↓
Conftest
       ↓
Terraform Apply
```

因此必须把 Rego 接入生产 Apply 前的**真实 Plan Gate**。

在没有完成这一点之前：

```text
Policy Rego = 有
Policy 单元测试 = 有
生产实际 Plan Enforcement = 未闭环
```

不能宣称 Policy Gate 已经完整保护生产 Apply。

---

# 3. 控制矩阵

## 3.1 Terraform 代码质量

| 控制 | 规则来源 | 实现 | CI | 证据 |
|---|---|---|---|---|
| fmt | IaC CI 规范 | Terraform | Policy Gate / PR | Actions Run |
| validate | IaC CI 规范 | Terraform | Policy Gate / PR | Actions Run |
| Bash syntax | CI 规范 | `bash -n` | PR | Actions Run |
| 敏感产物禁止入 Git | CI 规范 | shell 检查 | PR | Actions Run |

结论：**已形成基本闭环。**

---

# 4. Policy Gate 控制矩阵

| ID | 控制 | Rego | 负向测试 | PR Gate | 真实生产 Plan Gate |
|---|---|---:|---:|---:|---:|
| PG001 | 禁止 Delete | ✓ | ✓ | ✓ | **待闭环** |
| PG002 | 核心资源禁止 Replace | ✓ | ✓ | ✓ | **待闭环** |
| PG003 | 禁止 Owner | ✓ | ✓ | ✓ | **待闭环** |
| PG004 | 禁止 Contributor | ✓ | ✓ | ✓ | **待闭环** |
| PG005 | Storage 禁止公网 | ✓ | ✓ | ✓ | **待闭环** |
| PG006 | PostgreSQL 禁止公网 | ✓ | ✓ | ✓ | **待闭环** |
| PG007 | Tag 契约 | ✓ | ✓ | ✓ | **待闭环** |
| PG008 | 高危管理端口禁止公网 | ✓ | ✓ | ✓ | **待闭环** |
| PG009 | Unknown Action Fail Closed | ✓ | ✓ | ✓ | **待闭环** |

### 判断标准

```text
Rego 有规则
       ≠
生产受到规则保护
```

必须满足：

```text
真实 Plan JSON
    ↓
Policy Engine
    ↓
exit code != 0
    ↓
Apply 不允许继续
```

---

# 5. GitHub Ruleset / Branch Protection

## 5.1 CODEOWNERS

当前仓库存在：

```text
.github/CODEOWNERS
```

并覆盖：

```text
/infrastructure/terraform/
/.github/workflows/
```

但 CODEOWNERS 本身只是“推荐/指定 reviewer”，**是否强制必须由 Branch Protection / Ruleset 开启 required code owner review 来保证**。

所以：

```text
CODEOWNERS 存在
        ↓
不能直接推出
        ↓
Code Owner Review 必须通过
```

## 5.2 必须验证的 GitHub 控制

```text
main
 ├── Require PR
 ├── Require approvals
 ├── Require CODEOWNERS
 ├── Require status checks
 ├── Require branch up-to-date
 ├── Require conversation resolution
 ├── Restrict force push
 ├── Restrict deletion
 └── 明确 bypass 权限
```

### Bypass 是重点

生产安全不是“有没有规则”，而是：

```text
谁能绕过规则？
管理员能不能绕过？
Repository Admin 能不能直接 push？
Workflow 是否能自我批准？
Bot 是否具有 bypass 权限？
```

这些必须有实际 GitHub Ruleset 证据。

---

# 6. GitHub Environment Approval

Workflow 使用：

```text
environment: production
```

以及单独的生产审批 Workflow。

但是 YAML 中写：

```yaml
environment: production
```

**不等于已经存在 Required Reviewer。**

真正的控制链是：

```text
Workflow
 ↓
Environment
 ↓
Required Reviewers
 ↓
Deployment Protection Rule
 ↓
Job 才能继续
```

因此必须在 GitHub Environment 页面确认：

- Required reviewers
- Prevent self-review（如果业务需要）
- Deployment branch/tag policy
- Environment secrets
- 谁拥有环境管理权限

---

# 7. Azure OIDC / RBAC 一致性

当前 Apply Workflow 使用 Azure OIDC，而不是长期 Azure Service Principal Secret。

核心身份至少分成：

```text
AZURE_CLIENT_ID
    ↓
Quota / 受限能力

AZURE_APPLY_CLIENT_ID
    ↓
生产 Terraform Apply
```

Terraform 中还明确管理：

```text
Quota Request Operator
```

这说明 RBAC 已经进入 IaC，而不是完全依赖 Portal 手工操作。

---

# 8. Azure RBAC 审计不能只看 Terraform

必须同时检查三层：

```text
Terraform Code
       ↓
Terraform State
       ↓
Azure 实际 Role Assignment
```

理想状态：

```text
Code = State = Azure
```

如果：

```text
Code ≠ State
```

说明 IaC 纳管或 State 存在问题。

如果：

```text
State ≠ Azure
```

说明可能发生 Drift、权限变更或 Terraform Apply 异常。

---

# 9. Apply 权限审计

Apply 身份必须回答：

```text
它可以访问哪个 Subscription？
它可以修改什么 Resource Group？
它可以修改什么资源类型？
它能否创建 Role Assignment？
它能否修改权限？
它能否删除生产资源？
```

特别检查：

```text
Owner
User Access Administrator
Role Based Access Control Administrator
Contributor
```

如果 Apply 身份拥有这些高权限角色，必须证明：

1. 为什么需要。
2. Scope 是否最小。
3. 是否存在替代角色。
4. 是否由 Policy / Approval / Environment 形成补偿控制。
5. 是否有定期权限复核。

---

# 10. 资源生命周期控制

Policy Gate 不能只关注网络和 RBAC。

生产资源生命周期必须形成：

```text
Create
 ↓
Update
 ↓
Replace
 ↓
Delete
```

其中：

```text
Create → 一般允许
Update → 根据风险
Replace → 核心资源默认阻断
Delete → 默认阻断
```

这也是为什么 PG001 / PG002 必须在真实 Plan 上执行。

---

# 11. Drift 一致性

必须验证：

```text
Git Desired State
        ↓
Terraform State
        ↓
Azure Actual State
```

Drift Detection 应产生证据：

```text
检测时间
环境
Resource Address
Terraform State
Azure State
差异
差异来源
处理决定
处理人
```

不能只生成一个：

```text
Drift detected
```

而没有资源级证据。

---

# 12. 生产 Apply 的最终安全边界

理想流程：

```text
PR
 ↓
Quality Gate
 ↓
Security Scan
 ↓
Terraform Plan
 ↓
Plan JSON
 ↓
Policy Gate
 ↓
Risk Classification
 ↓
Required Review
 ↓
GitHub Environment Approval
 ↓
Apply Same Approved Plan
 ↓
Post-Apply Verification
 ↓
Evidence
```

最重要的一条：

> **审批的 Plan 必须和真正 Apply 的 Plan 是同一个不可变制品。**

不能出现：

```text
审批 Plan A
      ↓
重新 Plan
      ↓
Apply Plan B
```

否则审批实际上批准的是 A，生产执行的是 B。

---

# 13. 当前必须继续修复的项目

## P0

### P0-1 GitHub Ruleset

在仓库实际启用：

```text
main protection
PR required
CODEOWNER required
status checks required
no force push
no deletion
```

并保存 Ruleset ID / 配置证据。

### P0-2 真实 Production Plan 接入 Rego

生产 Apply 前：

```text
terraform plan -out=apply.tfplan
terraform show -json apply.tfplan > apply.tfplan.json
conftest test --policy policy/terraform --namespace terraform apply.tfplan.json
```

只有：

```text
Conftest PASS
+
Destructive Gate PASS
+
Approval PASS
```

才允许：

```text
terraform apply apply.tfplan
```

---

# 14. P1

- 将 Policy 规则拆成生命周期、网络、RBAC、Tag 等逻辑文件。
- 为每条 PG 规则建立独立 PASS / BLOCK 测试。
- 为真实 Plan 建立可重复的 Scenario Replay。
- 对 Apply Identity 做 Azure 实际 RBAC 清单审计。
- 对 GitHub Environment Required Reviewers 做定期审计。
- 对 Ruleset / Environment / OIDC / Azure RBAC 建立季度复核。

---

# 15. Production Ready 判定

必须同时满足：

```text
Docs 完整
  AND
Policy 有代码
  AND
Policy 有测试
  AND
Policy 被真实 Plan 调用
  AND
GitHub Ruleset 强制
  AND
Environment Approval 强制
  AND
Azure RBAC 最小化
  AND
Apply 使用批准的 Plan
  AND
Post-Apply 有验证
  AND
Evidence 可追溯
```

否则只能判定为：

```text
Production Ready = FAIL
```

而不是“基本可以”。

---

# 16. 审计原则

以后任何人修改：

```text
文档
Policy
Workflow
CODEOWNERS
Ruleset
Environment
Azure RBAC
```

都必须重新回答：

```text
这条规则在哪里定义？
 ↓
在哪里执行？
 ↓
谁负责阻断？
 ↓
如何证明执行了？
 ↓
如何证明绕不过去？
 ↓
出问题如何恢复？
```

**没有证据的治理规则，不算真正的治理规则。**
