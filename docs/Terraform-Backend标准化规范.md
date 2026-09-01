# Terraform Backend 标准化规范

> **一眼看懂：Backend 管 State；State 是 Terraform 生产变更的核心资产。**

## 1. 为什么必须治理 State

```text
Terraform Code = 期望配置
Terraform State = Terraform 认为资源是谁
Azure = 实际资源

Code ≠ State ≠ Azure
        ↓
Plan 负责发现差异
```

State 出错可能导致 Terraform 错误识别资源，从而产生误创建、误删除或 Replace。因此生产 State 必须远程、加锁、受控、可恢复、可审计。

## 2. 标准架构

```text
GitHub PR
   ↓
GitHub Actions
   ↓ OIDC
Azure
   ↓
Azure Storage Backend
   ├── State Blob
   ├── Blob Lease Lock
   ├── 加密
   ├── 版本/恢复
   └── 审计
```

生产禁止把本地 `terraform.tfstate` 作为唯一 State。

## 3. 环境隔离

不同环境必须使用独立 State，禁止共享。

```text
production → 独立 State
staging    → 独立 State
dev        → 独立 State
```

隔离目标不是“文件名不同”，而是确保一次错误 Apply 不会影响其他环境的资源集合。

## 4. Backend 最低标准

| 能力 | 要求 | 解决的问题 |
|---|---|---|
| 远程存储 | 必须 | 防止个人电脑成为单点 |
| State 锁 | 必须 | 防止并发写 State |
| 加密 | 必须 | 防止 State 泄露 |
| 最小权限 | 必须 | 降低误操作与越权 |
| 版本/恢复 | 必须 | 支持误操作恢复 |
| 审计 | 必须 | 追踪访问与变更 |

## 5. 标准变更流程

```text
修改 Terraform
 ↓
PR
 ↓
fmt / validate / scan
 ↓
Plan
 ↓
检查 Create / Update / Delete / Replace
 ↓
Policy Gate
 ↓
Review / Approval
 ↓
Apply
 ↓
验证
```

## 6. State Locked：先判断，后解锁

出现锁时：

1. 检查是否已有 GitHub Actions Apply。
2. 检查是否有人正在执行 Terraform。
3. 记录 Lock ID、持有者、时间。
4. 如果任务仍在执行，等待，不得强制解锁。
5. 只有确认是异常残留锁，才允许受控解锁。
6. 解锁后重新 Plan。
7. 如果突然出现大量 Destroy/Replace，立即停止。

> **禁止把 `force-unlock` 当成普通故障处理命令。**

## 7. State 异常/损坏

典型表现：

```text
State decode error
资源地址突然消失
大量资源突然 Destroy
原本稳定资源突然 Replace
```

标准流程：

```text
发现异常
 ↓
停止 Apply
 ↓
保存日志、Plan、State版本信息
 ↓
确认 Backend 历史版本
 ↓
必要时恢复可用版本
 ↓
重新 Plan
 ↓
确认没有意外 Destroy / Replace
 ↓
恢复流水线
```

**禁止直接手工编辑 State JSON。**

## 8. Import：接管已有 Azure 资源

```text
Azure 已存在
 ↓
盘点资源
 ↓
编写 Terraform Resource
 ↓
Import
 ↓
Plan
 ↓
补齐配置
 ↓
No unexpected changes
 ↓
正式纳管
```

Import 成功 ≠ 纳管完成。必须通过后续 Plan 校准。

## 9. Backend Migration

迁移前必须：

- 备份 State
- 停止并发 Apply
- 记录旧 Backend
- 记录新 Backend
- 执行迁移
- 验证资源地址与数量
- 执行 Plan
- 保存验证证据

## 10. 严禁操作

- 手工删除生产 State
- 手工编辑 State JSON
- 多个任务同时写同一 State
- 使用长期管理员凭据访问 Backend
- 未审批迁移 Backend
- 为了让流水线继续而关闭锁或 Policy
- Portal 修改资源后不处理 Drift

## 11. Production Ready 验收

```text
远程 Backend ✓
State 隔离 ✓
Lock 正常 ✓
权限最小化 ✓
恢复路径 ✓
审计能力 ✓
Import 流程 ✓
Plan 可验证 ✓

        ↓
Backend Production Ready
```
