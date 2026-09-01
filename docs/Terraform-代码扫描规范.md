# Terraform 代码扫描与质量规范

> **目标：在 Terraform 代码进入 Plan、Policy 和 Apply 之前，尽可能把语法错误、错误引用、安全问题和明显的生产风险挡住。**

## 1. 一眼看懂

```text
Terraform代码
 ↓
格式检查
 ↓
语法 / Provider / Module验证
 ↓
Lint
 ↓
安全扫描
 ↓
Secret扫描
 ↓
Terraform Plan
 ↓
变更风险检查
 ↓
Policy Gate
```

代码扫描解决“代码本身有没有明显问题”；Policy Gate 解决“这次具体变更允不允许”。两者不能互相替代。

---

# 2. 检查层级

| 层级 | 检查什么 | 失败处理 |
|---|---|---|
| Format | 文件格式 | 阻断 |
| Validate | HCL、Provider、Module | 阻断 |
| Lint | 代码质量、反模式 | 默认阻断 |
| Security | 云资源安全配置 | 高危阻断 |
| Secret | 密钥、Token、密码 | 立即阻断 |
| Plan | 实际资源变化 | 必须审查 |
| Policy | 生产治理规则 | 违反规则直接阻断 |

---

# 3. Format

执行：

```bash
terraform fmt -check -recursive
```

作用：统一格式，减少无意义 diff。

本地修复：

```bash
terraform fmt -recursive
```

格式问题不应该由 Review 人工判断。

---

# 4. Validate

执行：

```bash
terraform init -backend=false
terraform validate
```

主要检查：

- HCL 语法
- Resource 引用
- Variable 类型
- Module 输入输出
- Provider 配置
- Terraform 配置结构

注意：`validate` 通过不代表资源一定安全，也不代表 Plan 一定不会删除资源。

---

# 5. Lint

推荐使用 TFLint 等工具发现：

- 无效或可疑配置
- Provider 反模式
- 未使用变量
- 命名问题
- 云资源特定错误

Lint 应该逐步从“建议”升级为“生产必须通过”的规则。

---

# 6. 安全扫描

推荐使用 Checkov 等静态安全扫描工具。

重点检查：

```text
身份权限
网络暴露
存储加密
数据库公网访问
日志与监控
密钥管理
安全组 / NSG
资源配置基线
```

安全扫描的意义是提前发现已知不安全配置，但它不能理解全部业务风险。

例如：

```text
Checkov：配置本身符合安全基线

但

Plan：生产数据库被 Replace

→ 仍然必须阻断
```

---

# 7. Secret 检查

禁止把以下内容提交 Terraform：

- 密码
- Access Key
- Client Secret
- API Token
- 私钥
- 数据库连接密码

正确方向：

```text
Terraform
 ↓
Secret Reference / Identity
 ↓
Key Vault / CI Secret Store / OIDC
```

即使 Git 文件删除了 Secret，也不能认为泄露已经消失；一旦真实凭据暴露，应立即轮换。

---

# 8. Plan 风险检查

生成 Plan：

```bash
terraform plan -out=tfplan
terraform show -json tfplan > tfplan.json
```

必须关注：

```text
+ create
~ update
- destroy
-/+ replace
+/- create then destroy
```

其中最高风险通常是：

```text
核心数据库 destroy
核心数据库 replace
AKS replace
VNet / Subnet replace
Key Vault destroy
身份权限提升
公网边界变化
```

---

# 9. 大规模变更检查

一次 PR 如果突然出现大量资源变化，不能简单理解为“Terraform 正常”。

应检查：

1. Provider 是否升级？
2. Module 是否升级？
3. State 是否正确？
4. Backend 是否切换？
5. Resource 地址是否改变？
6. 是否漏了 `moved`？
7. 是否发生配置漂移？
8. 是否误用了 workspace / environment？

经验原则：**变化数量异常本身就是一个风险信号。**

---

# 10. 扫描失败怎么处理

```text
CI失败
 ↓
确认失败规则
 ↓
判断 False Positive 还是真实风险
 ↓
真实风险 → 修改代码
 ↓
False Positive → 有依据地豁免
 ↓
重新扫描
```

禁止为了让 CI 变绿直接关闭规则。

豁免必须说明：

- 规则 ID
- 资源
- 原因
- 风险评估
- 责任人
- 过期时间

---

# 11. 与 Policy Gate 的关系

```text
代码扫描
解决：代码是否明显不安全？

Plan
解决：这次到底要改变什么？

Policy Gate
解决：这个具体变化是否允许进入生产？

Approval
解决：人是否承担并批准这次生产变化？
```

因此生产 CI 不应只有 Checkov。

---

# 12. 验收标准

一个 Terraform PR 至少应做到：

```text
fmt PASS
validate PASS
lint PASS
security PASS
secret PASS
plan 可解释
policy PASS
review PASS
```

**任何一个高风险 Gate 失败，都不能通过“手工 Apply”绕过去。**
