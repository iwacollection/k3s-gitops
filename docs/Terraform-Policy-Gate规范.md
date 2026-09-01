# Terraform Policy Gate 生产规范

> **一句话理解：Policy Gate 不是“再跑一次 Checkov”，而是 Terraform Plan 进入生产前的最后一道机器风控门。**
>
> 它回答的问题是：**“这次代码变更最终准备对 Azure 做什么？这个动作是否允许发生？”**

---

## 1. 为什么必须有 Policy Gate

Terraform 的 `fmt`、`validate`、TFLint 和 Checkov 解决的问题不同：

| 检查 | 解决什么问题 | 能否判断业务风险 |
|---|---|---|
| `terraform fmt` | 格式统一 | 否 |
| `terraform validate` | Terraform 配置是否合法 | 否 |
| TFLint | Terraform 编码质量/潜在错误 | 部分 |
| Checkov | 常见 IaC 安全基线 | 部分 |
| **Terraform Plan** | 实际准备执行什么变更 | **是** |
| **Policy Gate** | 这次变更是否允许执行 | **是** |
| 人工审批 | 风险是否被业务/平台负责人接受 | 是 |

因此生产链路必须理解成：

```text
代码正确
   ↓
安全基线正确
   ↓
Plan 结果可解释
   ↓
Policy 判断风险
   ↓
人工审批
   ↓
Apply
```

**不能把 Checkov 通过理解为“可以生产 Apply”。**

---

# 2. Policy Gate 的边界

本仓库把策略分成四层：

```text
┌──────────────────────────────────────────┐
│ L4 人工审批                              │
│ 高风险变更最终责任确认                   │
├──────────────────────────────────────────┤
│ L3 Terraform Plan Policy Gate             │
│ 判断“准备做什么”是否允许                  │
├──────────────────────────────────────────┤
│ L2 IaC Security Scan                      │
│ Checkov / 安全基线                        │
├──────────────────────────────────────────┤
│ L1 Terraform Quality                     │
│ fmt / validate / lint                     │
└──────────────────────────────────────────┘
```

Policy Gate **不负责**：

- 替代 Terraform validate
- 替代 Checkov
- 替代 Azure Policy
- 替代生产审批
- 替代 Apply 后验证

Policy Gate **负责**：

- 阻断危险删除
- 阻断核心资源重建
- 阻断高危 RBAC
- 阻断公网暴露
- 阻断关键资源缺失治理 Tag
- 阻断高风险 NSG 管理端口暴露
- 对未知 Terraform action 默认失败

---

# 3. Policy Gate 标准执行链

```text
Pull Request
     │
     ├── Terraform fmt
     │
     ├── Terraform validate
     │
     ├── Checkov
     │
     └── Terraform Plan JSON
              │
              ▼
       tfplan.json
              │
              ▼
       Conftest / OPA
              │
       ┌──────┴──────┐
       │             │
     PASS           DENY
       │             │
       ▼             ▼
   进入审批       PR 失败
                     │
                     ▼
               修复 Terraform
```

关键点：**Policy 应尽可能检查 Plan JSON，而不是只检查 `.tf` 文本。**

因为最终风险发生在资源变更层，而不是文件层。

---

# 4. 当前策略目录

策略代码统一放在：

```text
policy/
└── terraform/
    └── terraform.rego
```

说明：

- `policy/`：所有策略即代码
- `terraform/`：Terraform Plan 策略
- `terraform.rego`：Open Policy Agent（OPA，开放策略代理）规则

以后策略扩大后建议继续拆分：

```text
policy/
├── terraform/
│   ├── lifecycle.rego
│   ├── network.rego
│   ├── rbac.rego
│   ├── tagging.rego
│   └── terraform.rego
│
└── kubernetes/
    ├── workload.rego
    └── security.rego
```

但在规则数量较少时，先保持单文件，避免过度工程化。

---

# 5. Policy 编号规范

所有生产阻断策略必须有稳定编号。

格式：

```text
PGxxx
```

例如：

```text
PG001
PG002
PG003
```

每条策略至少说明：

```text
规则编号
规则名称
风险
阻断条件
为什么阻断
如何修复
是否允许豁免
```

这样 CI 失败后，工程师不需要猜“为什么红了”。

---

# 6. 当前生产策略清单

## PG001：禁止生产资源删除

### 风险

Terraform Plan 出现：

```text
delete
```

可能意味着生产资源被销毁。

例如：

```text
-/+ resource
```

或者：

```text
- resource
```

### 策略

默认：**BLOCK**。

### 正确处理

如果确实要下线资源：

```text
提出变更
 ↓
确认业务已迁移
 ↓
确认依赖关系
 ↓
制定回滚方案
 ↓
专项审批
 ↓
执行下线
```

而不是直接修改 Terraform 然后 Apply。

---

## PG002：禁止核心资源 Replace

### 风险

Terraform 可能将资源识别成：

```text
delete + create
```

这意味着资源不是原地修改，而是重建。

对下面资源默认禁止：

- AKS
- PostgreSQL
- Key Vault
- VNet
- Subnet
- NSG
- Redis
- ACR

### 为什么危险

Replace 可能导致：

```text
资源 ID 改变
 ↓
Private Endpoint 断链
 ↓
DNS 关系变化
 ↓
权限关系变化
 ↓
业务连接失败
```

因此必须先判断：

```text
这是预期迁移？
还是 Terraform 配置错误导致的误判？
```

---

## PG003：禁止 Owner

生产 Terraform 不允许随意授予：

```text
Owner
```

原因：Owner 同时具备资源管理和权限管理能力，权限边界过大。

优先：

```text
具体资源角色
+
最小 scope
+
明确 principal
```

---

## PG004：禁止 Contributor

生产环境不允许把：

```text
Contributor
```

作为普通人员/服务账号的默认权限。

应该根据实际操作拆成：

```text
Reader
Network Contributor
AcrPull
AcrPush
Key Vault Secrets User
...
```

具体角色必须与实际职责匹配。

---

## PG005：Storage 禁止公网访问

默认阻断：

```text
public_network_access_enabled = true
```

推荐：

```text
Private Endpoint
      ↓
Private DNS
      ↓
VNet
      ↓
受控访问
```

如果确实存在业务公网访问需求，必须通过明确的例外流程，而不是修改规则让 CI 变绿。

---

## PG006：PostgreSQL 禁止公网访问

生产数据库默认要求：

```text
Private Network
```

目标：

```text
Application
   ↓
VNet
   ↓
Private Endpoint / Private Access
   ↓
PostgreSQL
```

避免：

```text
Internet
   ↓
PostgreSQL
```

---

## PG007：生产资源 Tag 契约

生产关键资源必须至少具备：

```text
Environment
Owner
ManagedBy
CostCenter
```

推荐最终统一为：

```text
Environment = production
Owner       = platform/team-name
ManagedBy   = terraform
CostCenter  = xxx
```

### 为什么 Tag 是治理能力而不是装饰

Tag 用于：

- 成本归属
- 资源负责人定位
- 自动化运维
- 资源盘点
- 漂移治理
- 事故响应
- 生命周期管理

例如生产故障时，可以快速回答：

```text
这个资源是谁负责？
属于哪个环境？
是否由 Terraform 管理？
成本属于哪个部门？
```

---

## PG008：NSG 高风险管理端口禁止公网开放

默认高风险端口包括：

```text
22      SSH
3389    RDP
2379    etcd client
2380    etcd peer
6443    Kubernetes API Server
10250   kubelet
```

禁止：

```text
0.0.0.0/0
        ↓
高风险管理端口
```

应该改成：

```text
固定办公网 CIDR
VPN
Jump Server
受控安全组
```

---

## PG009：未知动作默认失败

Terraform 未来可能增加新的 action 表达方式。

策略不能出现：

```text
未知 action
 ↓
被程序忽略
 ↓
CI 通过
```

正确模型：

```text
Unknown
   ↓
BLOCK
   ↓
人工确认
   ↓
升级 Policy Engine
```

这是生产系统非常重要的 **Fail Closed（失败关闭）** 原则。

---

# 7. 为什么 Policy Gate 必须 Fail Closed

安全 Gate 的默认逻辑应该是：

```text
明确允许 → PASS
明确禁止 → BLOCK
无法判断 → BLOCK
```

而不是：

```text
明确允许 → PASS
明确禁止 → BLOCK
无法判断 → PASS
```

因为第三种逻辑会形成：

```text
新 Terraform 资源
      ↓
Policy 不认识
      ↓
Policy 没报错
      ↓
CI 通过
      ↓
生产 Apply
```

这就是典型的安全策略失效。

---

# 8. Policy 与 Azure Policy 的关系

两者不是替代关系。

```text
GitHub PR
   ↓
Terraform Policy Gate
   ↓
人工审批
   ↓
Terraform Apply
   ↓
Azure Policy
   ↓
Azure Resource
```

### Terraform Policy Gate

回答：

> “这次代码变更能不能进入生产？”

### Azure Policy

回答：

> “即使有人绕过 Terraform，Azure 最终是否允许这个资源状态存在？”

因此生产应该采用：

```text
Git 层防线
+
CI 层防线
+
Azure 控制面防线
```

形成纵深防御。

---

# 9. Policy 豁免规范

不能出现：

```text
# skip policy
```

然后就直接通过。

任何例外必须具备：

```text
Policy ID
资源
原因
风险评估
替代控制措施
审批人
过期时间
关联 Issue/PR
```

例如：

```text
PG005
资源：xxx
原因：第三方系统暂不支持 Private Endpoint
补偿措施：IP Allowlist + WAF + 监控
审批：Platform Owner
过期时间：2026-12-31
Issue：#123
```

### 豁免必须有过期时间

禁止永久豁免。

```text
Exception
   ↓
Expires
   ↓
重新评估
```

这样可以避免临时方案永久化。

---

# 10. Policy Gate 失败后的处理方式

看到：

```text
PG002 BLOCK
```

不要第一反应去改 Policy。

正确顺序：

```text
CI 失败
  ↓
查看 PG 编号
  ↓
查看具体 Resource Address
  ↓
查看 Terraform Plan
  ↓
确认是否预期
  ↓
如果非预期：修 Terraform
  ↓
重新 Plan
  ↓
重新 Policy
```

只有确认规则本身错误时，才修改 Policy。

---

# 11. 一个完整生产案例

假设开发人员修改：

```hcl
public_network_access_enabled = true
```

流程：

```text
开发修改 Terraform
        ↓
Pull Request
        ↓
terraform validate
        ↓
Checkov
        ↓
Terraform Plan
        ↓
Plan JSON
        ↓
PG006
        ↓
发现 PostgreSQL 公网访问
        ↓
BLOCK
```

PR 不允许进入生产 Apply。

如果开发人员继续说：

> “业务要求公网访问。”

不能直接删除 PG006。

应该进入：

```text
例外申请
 ↓
风险评估
 ↓
补偿控制
 ↓
审批
 ↓
带期限豁免
```

---

# 12. Policy Gate 与 Plan Approval 的职责边界

这是生产 IaC 最容易混淆的地方。

### Policy Gate

机器判断：

```text
规则是否允许
```

### Approval

人判断：

```text
业务是否允许
```

例如：

```text
Plan:
修改生产 AKS Node Pool
```

Policy：

```text
没有违反禁止规则
→ PASS
```

但这不代表：

```text
→ 自动 Apply
```

仍然必须：

```text
Plan Review
   ↓
业务/平台确认
   ↓
Production Approval
   ↓
Apply
```

---

# 13. Policy Gate 最终标准

生产 IaC 必须满足：

```text
[代码质量]
fmt
validate
lint

        ↓

[安全基线]
Checkov

        ↓

[变更风险]
Terraform Plan

        ↓

[策略判断]
OPA / Conftest

        ↓

[人工责任]
Production Approval

        ↓

[执行]
Terraform Apply

        ↓

[结果]
Azure/Kubernetes Verification
```

最终原则：

> **CI 不是为了让流水线变绿，而是为了让“不应该发生的生产变化”根本没有机会进入 Apply。**
