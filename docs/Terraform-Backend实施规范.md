# Terraform Backend 实施规范

> **Terraform State 是生产 IaC 的核心状态资产。代码丢了可以恢复，State 映射错误可能直接导致 Terraform 对真实资源做出错误判断。**

## 1. 一眼看懂

```text
Terraform Code
      ↓
Terraform State
      ↓
Azure Resource ID
```

State 负责告诉 Terraform：

```text
“代码里的这个 resource
到底对应云上的哪个真实资源。”
```

生产 State 必须远端、隔离、可恢复、可审计。

---

# 2. Backend 标准

生产推荐使用 Azure Storage Backend。

```text
Azure Storage Account
└── terraform-state
    ├── dev/terraform.tfstate
    ├── staging/terraform.tfstate
    └── production/terraform.tfstate
```

实际项目可进一步按 subscription / environment / workload 拆分。

---

# 3. 为什么不能把 State 放 Git

State 可能包含：

- Resource ID
- Resource 属性
- 输出值
- Provider 状态
- 某些敏感信息引用

同时多人并发操作本地 State 会产生：

```text
工程师A读取旧State
工程师B读取旧State
 ↓
A Apply
 ↓
B Apply
 ↓
状态竞争 / 覆盖 / 错误判断
```

所以生产 State 不允许通过 Git 管理。

---

# 4. State 锁与并发

同一 State 同一时间只允许一个变更操作。

```text
Production State
      ↓
Lock
 ┌────┴────┐
Apply A   Apply B
   ↓        ↓
执行       等待
```

CI 还应该增加 Workflow Concurrency，形成“双层保护”：

```text
GitHub Actions Concurrency
          ↓
Terraform Backend Lock
```

---

# 5. 权限模型

State 存储必须遵循最小权限。

```text
Plan Identity
→ 只读或必要的读取权限

Apply Identity
→ 只允许目标 Scope 的写权限

Developer
→ 不直接拥有生产 State 写权限
```

禁止所有环境共用一个高权限身份。

---

# 6. State 生命周期

```text
创建 Backend
 ↓
初始化 Terraform
 ↓
State 写入远端
 ↓
日常 Plan / Apply
 ↓
版本保护
 ↓
备份 / 恢复
 ↓
灾难恢复演练
```

Backend 本身也属于生产基础设施，必须纳入治理。

---

# 7. 已有资源接管

禁止为了“让 Terraform 管理”而重新创建已经存在的生产资源。

标准流程：

```text
Azure资源盘点
 ↓
确认 Resource ID
 ↓
Terraform Resource 定义
 ↓
terraform import
 ↓
terraform plan
 ↓
消除差异
 ↓
No unexpected changes
```

如果 Plan 出现 Destroy / Replace：立即停止，不得为了让 Plan 变绿直接 Apply。

---

# 8. Resource Address 变化

例如：

```text
module.network.azurerm_virtual_network.main
```

变成：

```text
module.network.azurerm_virtual_network.primary
```

Terraform 可能认为：

```text
旧资源删除
新资源创建
```

这种重构应评估 `moved` block 或 State migration。

---

# 9. State 损坏 / 丢失处理

第一原则：**不要重新创建生产资源。**

排查：

```text
State 是否真的丢失？
 ↓
Backend 是否可访问？
 ↓
是否只是本地初始化错误？
 ↓
是否存在历史版本？
 ↓
Resource ID 是否仍然存在？
```

恢复后必须执行：

```text
terraform refresh / plan
 ↓
检查资源映射
 ↓
确认无意外 Destroy
```

---

# 10. Backend 迁移

Backend 迁移属于高风险操作。

必须：

1. 冻结并发 Apply
2. 备份现有 State
3. 验证新 Backend
4. 执行迁移
5. 检查 State Resource 数量
6. 执行 Plan
7. 确认没有大规模 Destroy / Create

不能直接修改 Backend 后就 Apply。

---

# 11. State 操作审计

以下命令都属于高风险操作：

```bash
terraform state mv
terraform state rm
terraform import
terraform init -migrate-state
```

必须记录：

- 操作人
- 原地址
- 新地址
- Resource ID
- 操作原因
- 操作前后 Plan

---

# 12. 验收标准

生产 Backend 必须满足：

```text
远端存储
环境隔离
并发保护
最小权限
版本恢复
可审计
可演练
```

**Backend 不是 Terraform 的“配置项”，而是生产基础设施治理的一部分。**
