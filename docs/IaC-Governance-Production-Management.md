# 企业级 IaC 生产治理规范

> **这份文档回答一个核心问题：生产基础设施到底由谁、通过什么流程、在什么权限下、以什么证据进行变更？**

## 0. 一眼看懂

```text
需求
 ↓
Terraform代码 / Module
 ↓
Pull Request
 ↓
代码质量 Gate
 ↓
安全扫描 Gate
 ↓
Terraform Plan
 ↓
Policy Gate（允许/阻断）
 ↓
人工 Review
 ↓
Production Approval
 ↓
受保护的 Apply
 ↓
Post-Apply Verification
 ↓
Drift Detection
 ↓
审计 / 持续治理
```

四个对象必须始终区分：

| 对象 | 人话解释 | 不能做什么 |
|---|---|---|
| Git | 我们希望基础设施变成什么样 | 不能代表真实资源状态 |
| Terraform State | Terraform 认为哪个代码对象对应哪个真实资源 | 不能当业务配置库 |
| Azure | 云上的真实资源 | 不能成为绕过 Git 的配置入口 |
| Terraform Plan | 这次准备改变什么 | 不是审批本身 |

---

# 1. 管理边界

## 1.1 哪些资源必须纳入 IaC

原则：**长期存在、影响生产、需要审计或需要重复创建的基础设施必须代码化。**

包括但不限于：

- Resource Group
- VNet / Subnet / Route Table / NSG
- AKS / ACR
- Database
- Storage Account
- Key Vault
- Managed Identity / RBAC
- Monitoring / Diagnostic Settings

临时测试资源可以不纳管，但必须有生命周期负责人和清理策略。

## 1.2 谁负责什么

| 角色 | 责任 |
|---|---|
| Developer | 提交变更、说明业务目的 |
| Module Owner | 保证模块接口和兼容性 |
| SRE / Cloud Owner | 审查生产风险 |
| Security | 审查高风险安全策略 |
| CI | 自动执行质量、安全、Policy 检查 |
| Terraform Apply Identity | 仅执行获批准的变更 |

---

# 2. Module 与 Environment 的边界

```text
modules/
   ↓ 提供“怎么创建”

environments/
   ↓ 决定“这个环境创建什么、使用什么参数”

production/
   ↓ 生产实例

Terraform State
   ↓
Azure
```

Module 禁止保存：

- 生产订阅 ID
- 生产密码
- 环境专属资源名
- 环境专属网络地址

Environment 负责：

- region
- SKU
- capacity
- feature flags
- 资源组合

---

# 3. 生产变更标准

## 3.1 正常变更

```text
Issue / Change Request
 ↓
修改 Terraform
 ↓
PR
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
Approval
 ↓
Apply
 ↓
Verification
```

## 3.2 禁止变更

以下操作默认禁止：

- 本地直接对生产执行 `terraform apply`
- 本地保存生产 State
- Portal 修改 Terraform 管理资源后不回写代码
- 绕过 Policy Gate
- 绕过 Environment Approval
- 删除或覆盖 Terraform State
- 使用长期 Azure Secret 作为 CI 身份

---

# 4. 变更风险分级

| 等级 | 示例 | 默认处理 |
|---|---|---|
| L1 | Tag、描述、非关键参数 | 自动检查 + Review |
| L2 | 普通计算资源扩容 | Review + Plan |
| L3 | 网络、RBAC、Key Vault、数据库参数 | 强制 Policy + Approval |
| L4 | Delete / Replace 核心资源、生产网络边界、身份权限提升 | 默认阻断，专项审批 |

核心原则：**不是所有 Plan 都应该拥有同样的 Apply 权限。**

---

# 5. State 治理

生产 State 必须使用远端 Backend，并进行环境隔离。

```text
Azure Storage Backend
 ├── dev
 ├── staging
 └── production
```

要求：

- State 不进入 Git
- State 访问使用最小权限
- 开启版本保护和恢复能力
- 避免多人同时操作
- 生产 State 变更必须可审计

State 丢失时**不要重新创建资源**，优先恢复 State 或重新建立资源映射。

---

# 6. 已有资源接管

```text
Azure Existing Resource
 ↓
资产盘点
 ↓
Terraform Resource 定义
 ↓
terraform import
 ↓
terraform plan
 ↓
消除差异
 ↓
No changes
 ↓
正式纳管
```

出现 `destroy` 或 `-/+ replace` 时不得直接 Apply。

必须先判断：

1. State 是否正确？
2. Resource ID 是否正确？
3. Provider 是否发生行为变化？
4. 配置是否缺失？
5. Azure 是否存在人工漂移？

---

# 7. 安全治理

安全控制分成四层：

```text
代码层
 ↓
Security Scan
 ↓
Plan层
 ↓
Policy Gate
 ↓
身份层
 ↓
RBAC / OIDC
 ↓
平台层
 ↓
Azure Policy / Resource Protection
```

其中：

- Checkov 主要发现已知安全错误模式
- Policy Gate 判断这次具体变更是否允许进入生产
- RBAC 控制“谁能做”
- Approval 控制“这次是否批准”
- Azure Policy 控制云平台最终边界

任何一层失败，都不能通过“换一种命令”绕过。

---

# 8. Apply 安全边界

Apply 必须满足：

```text
代码来自受保护分支
 AND
CI检查通过
 AND
Plan 与审批对象一致
 AND
Policy Gate通过
 AND
生产环境审批通过
 AND
执行身份权限足够但不过度
```

特别重要：**批准的是具体 Plan，而不是一句“这个 PR 可以”。**

如果代码或 Plan 在批准后发生变化，应重新生成 Plan 并重新审批。

---

# 9. Apply 后验证

Apply 成功不等于变更成功。

必须验证：

```text
Terraform Apply
 ↓
Terraform State
 ↓
Azure Resource
 ↓
业务可用性
```

例如 AKS：

- Cluster 状态正常
- Node Ready
- API 可访问
- Ingress / HTTPS 正常
- ACR 拉取正常

网络资源：

- VNet / Subnet 正常
- Route 正常
- NSG 生效

数据库：

- 服务状态正常
- 网络访问正常
- 关键连接测试通过

---

# 10. Drift 治理

漂移就是：

```text
Terraform代码 / State
        ≠
Azure实际状态
```

处理原则：

```text
发现 Drift
 ↓
判断是否授权变更
 ├── 是 → 将变更回写 Terraform
 └── 否 → 恢复 Terraform 期望状态
```

禁止简单执行 `terraform apply` 后就认为问题解决。必须先理解漂移来源。

---

# 11. 故障处理标准

统一使用：

```text
现象
 ↓
判断 / 排查
 ↓
证据
 ↓
止损
 ↓
恢复
 ↓
验证
 ↓
长期治理
```

例如 Plan 突然要删除生产数据库：

```text
现象：Plan 出现 destroy
 ↓
停止 Apply
 ↓
保存 Plan / State / Resource ID
 ↓
检查 State 映射
 ↓
检查配置和 Provider
 ↓
确认数据库真实状态
 ↓
修复代码或 State
 ↓
重新 Plan
 ↓
确认 No unexpected changes
```

---

# 12. 审计证据

一次生产变更至少应能够追溯：

```text
谁提出
 ↓
改了什么
 ↓
为什么改
 ↓
Plan 是什么
 ↓
Policy 是否通过
 ↓
谁审批
 ↓
谁执行
 ↓
执行结果
 ↓
验证结果
```

因此 CI 产物、Plan、审批记录、Apply 日志和验证结果都属于生产治理证据。

---

# 13. 最终判断标准

一个“生产 Ready”的 IaC 仓库不是“Terraform 能跑”，而是能够回答：

- 什么资源由 Terraform 管？
- 谁可以改？
- 怎么提交？
- 什么检查必须通过？
- 什么变更绝对不能做？
- 什么变更需要审批？
- Apply 用什么身份？
- State 怎么保护？
- 已有资源怎么接管？
- Drift 怎么发现？
- Apply 后怎么验证？
- 失败怎么止损和恢复？
- 所有动作怎么审计？

**最终目标：把“会写 Terraform”升级为“能够安全运营生产基础设施”。**
