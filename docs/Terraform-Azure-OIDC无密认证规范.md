# Terraform Azure OIDC 无密认证规范

> **目标：GitHub Actions 不保存长期 Azure 密钥；CI 每次执行都通过短生命周期身份获得最小权限。**

## 1. 一眼看懂

```text
GitHub Actions
      ↓
OIDC Token
      ↓
Azure Entra ID
      ↓
Federated Credential
      ↓
对应环境的 Terraform Identity
      ↓
Azure RBAC
      ↓
目标 Resource / Resource Group / Subscription
```

核心思想：**身份与环境绑定，权限与任务绑定，凭据不长期保存。**

---

# 2. 为什么不用长期 Secret

传统方式：

```text
Client ID + Client Secret
        ↓
GitHub Secrets
        ↓
长期有效
```

风险：

- 泄露后有效期长
- 难判断谁使用
- Secret 轮换成本高
- 不容易做到环境隔离

OIDC：

```text
Workflow运行
 ↓
获取短期Token
 ↓
Azure验证来源
 ↓
签发访问身份
 ↓
执行任务
```

---

# 3. 身份隔离

推荐：

```text
dev workflow
   ↓
dev identity

staging workflow
   ↓
staging identity

production workflow
   ↓
production identity
```

禁止：

```text
所有环境
   ↓
一个 Owner 身份
```

---

# 4. Trust 边界

Federated Credential 必须尽可能限制：

- GitHub Organization
- Repository
- Branch / Environment
- Workflow 来源

生产身份不应该信任任意分支。

目标：

```text
只有受保护的 production workflow
 ↓
才能获得 production identity
```

---

# 5. 权限分层

不要直接给 Terraform Identity 全订阅 Owner。

推荐按任务拆分：

```text
Plan Identity
 ↓
读取资源状态

Apply Identity
 ↓
修改目标资源

专项 Identity
 ↓
高风险权限操作
```

Scope 尽量从：

```text
Subscription
```

缩小到：

```text
Resource Group
```

甚至具体资源。

---

# 6. Plan 与 Apply 权限必须不同

```text
Pull Request
 ↓
Plan Identity
 ↓
Read
```

生产执行：

```text
Approved PR
 ↓
Production Environment
 ↓
Apply Identity
 ↓
Write
```

这样即使 PR 阶段被恶意利用，也不会天然获得生产写权限。

---

# 7. 高风险权限

以下操作必须特别审查：

- Owner
- Contributor
- User Access Administrator
- Role Assignment
- Key Vault 管理权限
- 网络边界修改

尤其要防止 Terraform 自己给自己扩大权限：

```text
Terraform Identity
      ↓
给自己 Contributor / Owner
```

应该由 Policy Gate 直接阻断。

---

# 8. Production Approval

OIDC 解决“身份是谁”。

它不能解决“这次变更是否应该执行”。

因此必须组合：

```text
OIDC
 ↓
身份可信

RBAC
 ↓
权限最小

Policy Gate
 ↓
变更符合规则

Approval
 ↓
人为批准
```

---

# 9. 泄露与撤销

如果发现身份异常：

```text
发现异常
 ↓
禁用 Federated Credential / Identity
 ↓
检查 GitHub Workflow
 ↓
检查 Azure Activity Log
 ↓
确认影响范围
 ↓
恢复权限
```

OIDC 不代表不需要安全审计。

---

# 10. 验收清单

```text
□ 没有长期 Azure Secret
□ dev/staging/prod 身份隔离
□ production 仅受保护来源可获取
□ Plan / Apply 权限分离
□ Scope 最小化
□ 高风险 RBAC 有 Policy
□ Production 有 Approval
□ Azure Activity Log 可追踪
□ 身份异常有撤销方案
```

**最终目标：CI 即使被滥用，也尽量只能获得当前环境、当前任务所需要的最小权限。**
