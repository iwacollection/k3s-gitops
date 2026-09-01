# IaC Production Ready 验收报告

> **一眼看懂：Terraform 能执行，不等于 IaC 可以安全管理生产。**

## 1. 验收目标

判断仓库是否具备：

```text
代码质量
 + 安全扫描
 + Policy Gate
 + Remote State
 + Lock / Recovery
 + OIDC / 最小权限
 + PR / Review / Approval
 + Apply / Verification
 + Drift
 + 审计 / 回滚
 = Production Ready
```

## 2. P0 阻断项

以下任意一项失败，都不能宣布 Production Ready：

- 生产使用本地 State
- 无 State Lock
- CI 使用长期 Azure Secret
- 开发者可绕过审批直接 Apply
- Policy Gate 可被任意关闭
- 未预期 Delete / Replace 可以直接进入 Apply
- 没有 State 恢复路径
- 无法追踪生产变更责任人

## 3. 验收矩阵

| 类别 | 验收项 | 必须达到 |
|---|---|---|
| Git | main / PR 保护 | ✓ |
| Git | CODEOWNERS | ✓ |
| Terraform | fmt / validate | ✓ |
| Terraform | Provider 锁定 | ✓ |
| Security | Secret Scan | ✓ |
| Security | Checkov | ✓ |
| Policy | Policy Gate | ✓ |
| State | Remote Backend | ✓ |
| State | Lock | ✓ |
| State | Recovery | ✓ |
| IAM | OIDC | ✓ |
| IAM | 最小权限 | ✓ |
| Change | Review / Approval | ✓ |
| Resource | Naming / Tag / Owner | ✓ |
| Operations | Drift Detection | ✓ |
| Recovery | Apply Failure | ✓ |
| Recovery | Rollback | ✓ |
| Audit | Evidence | ✓ |

## 4. CI/CD 验收

```text
Pull Request
 ↓
fmt
 ↓
validate
 ↓
lint
 ↓
Security Scan
 ↓
Plan
 ↓
Plan JSON
 ↓
Policy Gate
 ↓
Review
 ↓
Production Approval
 ↓
Apply
 ↓
Verification
```

必须证明每一阶段的失败都能阻断下一阶段。

## 5. Plan 验收

重点检查：

```text
Create  → 是否必要
Update  → 是否有业务影响
Delete  → 是否明确批准
Replace → 是否存在停机/数据风险
```

未预期的 Delete / Replace 必须停止流水线。

## 6. 安全验收

必须验证：

- Secret 不进入 Git
- Azure 使用 OIDC
- RBAC 遵守最小权限
- 数据库/存储公网访问符合策略
- NSG 高风险管理端口受控
- Policy Gate 能真正阻断违规 Plan

## 7. State 验收

```text
Remote ✓
Lock ✓
Encryption ✓
Recovery ✓
Access Control ✓
Audit ✓
```

至少实际演练一次 State 恢复，而不是只存在文档描述。

## 8. 故障演练

必须能够处理：

- State Locked
- State 异常
- Plan Destroy
- Plan Replace
- Drift
- Apply 失败
- Apply 部分成功
- 紧急变更

## 9. 审计证据

验收时保存：

```text
PR
 ↓
CI Run
 ↓
Plan 摘要
 ↓
Policy 结果
 ↓
Approval
 ↓
Apply
 ↓
Verification
 ↓
State 版本
```

## 10. 最终判定

```text
P0 全部通过
+ 核心流程验证成功
+ 故障恢复演练成功
+ 审计证据完整
        ↓
        PASS
        ↓
IaC Production Ready
```
