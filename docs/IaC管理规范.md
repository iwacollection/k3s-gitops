# IaC 管理规范

> **一眼看懂：IaC 管理的是生产基础设施的生命周期，而不只是 Terraform 文件。**

## 1. 管理闭环

```text
需求 → 设计 → PR → 自动检查 → Plan → Policy Gate → Review/Approval → Apply → 验证 → 审计 → Drift 管理
```

任何关键阶段失败，都停止向下执行。

## 2. 仓库边界

```text
负责：Azure / Kubernetes 基础设施、网络、安全、权限、监控基础能力、Terraform State
不负责：应用镜像、业务代码、应用 CI/CD、业务服务发布
```

## 3. 目录职责

```text
modules/    创建资源的标准能力
production/ 生产环境实际组合
policy/     禁止什么
.github/    什么条件才能执行
docs/       为什么这样做、出了问题怎么办
```

## 4. 资源 Ownership

每个生产资源必须明确：

- Owner
- Purpose
- Environment
- Resource Group
- 命名
- Tag
- 依赖关系
- 修改权限

## 5. 新增资源

```text
需求
 ↓
确认 Owner / 成本 / 依赖 / 安全边界
 ↓
选择或设计 Module
 ↓
PR
 ↓
fmt / validate / lint / security scan
 ↓
Plan
 ↓
Policy Gate
 ↓
Review / Approval
 ↓
Apply
 ↓
资源健康验证
 ↓
记录结果
```

## 6. 修改资源

必须首先查看 Plan：

```text
Create  → 是否符合预期
Update  → 是否影响业务
Delete  → 为什么删除
Replace → 为什么必须重建
```

出现未预期 Delete/Replace 时，**禁止继续 Apply**。

## 7. 删除资源

生产删除必须确认：

1. 业务确认
2. 依赖关系
3. 数据备份/保留策略
4. 影响范围
5. 回滚方案
6. Policy Gate
7. Production Approval

## 8. 扩容

先判断瓶颈，再决定扩容方式：

```text
CPU / Memory / IO / 网络 / 连接数 / 存储
            ↓
确认瓶颈
            ↓
纵向 or 横向扩容
            ↓
Plan
            ↓
成本与容量检查
            ↓
Apply
            ↓
业务指标验证
```

## 9. 接管已有资源

```text
Azure 资源盘点
 ↓
Terraform Resource
 ↓
Import
 ↓
Plan
 ↓
配置校准
 ↓
No unexpected changes
 ↓
正式纳管
```

Import 成功不等于纳管完成。

## 10. Module 修改

修改 Module 前必须评估：

- 所有调用方
- Provider schema
- 默认值变化
- Resource 地址变化
- ForceNew
- State migration
- 是否产生 Replace/Delete

## 11. Provider 升级

```text
Changelog
 ↓
锁定版本
 ↓
init -upgrade
 ↓
validate
 ↓
Plan
 ↓
检查 schema / Replace
 ↓
Review
 ↓
Apply
 ↓
验证
```

## 12. Drift 管理

```text
Git 期望状态
      ≠
Azure 实际状态
      ↓
发现 Drift
      ↓
判断来源
 ┌────┴────┐
应保留     不应保留
 ↓          ↓
回写代码    恢复期望状态
```

Portal 修改不是长期管理方式。

## 13. 权限边界

```text
开发者 → PR / Review
CI → OIDC + 最小权限
生产 Apply → Approval + 受控身份
```

禁止长期 Azure Secret、共享管理员身份和开发者直接生产 Apply。

## 14. 完成定义

生产变更只有同时满足以下条件才算完成：

- Plan 与预期一致
- Policy Gate 通过
- Approval 完成
- Apply 成功
- 资源健康验证通过
- State 正常
- 无未解释 Drift
- 日志和证据可追溯

## 15. 禁止事项

- 直接生产 `terraform apply`
- 绕过 PR / Approval
- 关闭安全检查换取 CI 通过
- 永久 Policy 豁免
- 手工编辑 State
- 未解释 Destroy/Replace 直接执行
- Portal 长期修改 IaC 管理资源
