# Terraform Module 治理规范

> **Module 的目的不是少写几行 Terraform，而是把基础设施能力封装成稳定、可复用、可审计的产品接口。**

## 1. 一眼看懂

```text
Environment
   ↓ 输入环境参数
Module
   ↓ 封装资源创建逻辑
Resource
   ↓
Terraform State
   ↓
Cloud Resource
```

Module 负责“怎么创建”；Environment 负责“在哪里、创建什么、用什么参数”。

---

# 2. 标准目录

```text
modules/
├── network/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── versions.tf
│   ├── README.md
│   └── examples/
├── aks/
├── acr/
├── monitoring/
├── identity/
└── database/
```

推荐进一步增加：

```text
modules/<module>/
├── tests/
└── CHANGELOG.md
```

---

# 3. Module 应该负责什么

以 Network Module 为例：

```text
输入
├── address_space
├── subnet definitions
├── tags
└── feature flags

Module
├── VNet
├── Subnet
├── Route Table
└── NSG

输出
├── vnet_id
├── subnet_ids
└── nsg_ids
```

Module 应该隐藏资源实现细节，只暴露稳定接口。

---

# 4. Module 不应该负责什么

禁止把环境业务逻辑塞进 Module：

```text
❌ if production then ...
❌ hardcode production subscription
❌ hardcode production CIDR
❌ hardcode password
❌ hardcode真实生产资源名称
```

推荐：

```text
production
   ↓ variables
network module
```

---

# 5. 输入输出契约

每个 Variable 必须说明：

- 类型
- 是否必填
- 默认值
- 允许范围
- 安全影响
- 变更是否可能触发 Replace

例如：

```hcl
variable "node_count" {
  description = "AKS node count"
  type        = number

  validation {
    condition     = var.node_count >= 1
    error_message = "node_count must be >= 1"
  }
}
```

Output 必须明确用途，禁止输出密码、Token 等敏感值。

---

# 6. Provider 与版本治理

Module 应声明自己兼容的 Terraform / Provider 范围。

原则：

```text
升级 Provider
 ↓
先测试 Module
 ↓
再测试 Environment
 ↓
生成 Plan
 ↓
确认没有异常 Replace
 ↓
再进入生产
```

禁止生产环境直接追踪未经验证的最新 Provider。

---

# 7. 破坏性变更

Module 修改可能导致：

```text
资源地址变化
 ↓
Terraform认为是新资源
 ↓
旧资源 destroy
 ↓
新资源 create
```

因此 Module 重构必须检查：

- Resource address
- `moved` block
- ForceNew 属性
- State migration
- Provider 行为变化

特别是重命名资源时，优先考虑 `moved`，避免无意义重建。

---

# 8. Module 生命周期

```text
设计
 ↓
开发
 ↓
单元测试
 ↓
示例环境验证
 ↓
生产环境 Plan
 ↓
发布
 ↓
维护
 ↓
废弃
```

Module 删除不能只删除目录。

必须确认：

- 哪些 Environment 正在使用
- 哪些 State 正在引用
- 是否存在旧版本依赖
- 是否需要迁移

---

# 9. Module 测试

至少覆盖：

```text
正常输入
边界输入
非法输入
默认值
关键安全配置
关键 Output
```

生产关键 Module 还应验证：

- 不会意外 Destroy
- 不会意外 Replace
- 网络边界符合预期
- RBAC 最小权限
- Tag 完整

---

# 10. Module Review 清单

Review 时依次问：

```text
① 接口是否稳定？
② 环境配置有没有泄漏进 Module？
③ 是否新增高风险权限？
④ 是否可能触发 Replace？
⑤ 是否改变 Resource Address？
⑥ 是否需要 moved？
⑦ 是否新增公网入口？
⑧ 是否保证 Tag？
⑨ 是否有测试？
⑩ 是否更新文档和示例？
```

---

# 11. Module 与 Policy Gate

Module 本身必须遵守平台规则；但不能只依赖 Module 保证安全。

```text
Module设计
 ↓
代码扫描
 ↓
Plan
 ↓
Policy Gate
```

因为同一个 Module 在不同 Environment 可能产生完全不同的风险。

---

# 12. 版本与兼容性

推荐：

```text
Module版本
 ↓
CHANGELOG
 ↓
兼容性说明
 ↓
升级指南
```

升级必须回答：

- 新增什么？
- 删除什么？
- 哪些输入变化？
- 哪些资源可能 Replace？
- State 是否需要迁移？
- 回滚怎么做？

---

# 13. 验收标准

一个合格 Module 应做到：

```text
职责单一
接口清晰
环境无耦合
版本可控
测试存在
文档完整
风险可预测
迁移可执行
```

**Module 是基础设施平台的“软件组件”，不是一堆 Terraform 文件。**
