# IaC Production Ready 验收报告

> **一句话：Terraform 能执行，不等于 IaC 可以安全管理生产；Production Ready 必须用真实检查和证据证明。**

## 1. 验收基本信息

| 字段 | 内容 |
|---|---|
| Repository | `iwacollection/k3s-gitops` |
| Branch | `main` |
| Commit SHA | |
| 验收环境 | production / staging / dev |
| Terraform 版本 | |
| Provider 版本 | |
| Backend | |
| 验收日期 | |
| 验收人 | |
| Reviewer | |
| 最终结论 | PASS / PASS WITH EXCEPTION / FAIL |

---

## 2. Production Ready 判断模型

```text
代码质量
 +
Security Scan
 +
Policy Gate
 +
Remote State
 +
Lock / Recovery
 +
OIDC / Least Privilege
 +
PR / Review / Approval
 +
Apply 控制
 +
Verification
 +
Drift
 +
Rollback / Recovery
 +
Audit Evidence
 =
Production Ready
```

**所有 P0 项通过后，才能进入最终判定。**

---

## 3. P0 阻断项

任意一项失败，最终结论必须为 `FAIL`：

- 生产使用本地 State 作为唯一 State
- State 无并发锁
- State 没有恢复路径
- CI 使用长期 Azure Secret 作为生产身份
- 开发者可以绕过审批直接 Apply
- Policy Gate 可以通过简单修改 PR/参数任意关闭
- 未预期 Delete / Replace 可以进入生产 Apply
- 无法追踪生产变更责任人
- 生产 Apply 没有可靠审计证据
- State 与实际资源关系无法确认

---

## 4. 验收矩阵

| 类别 | 验收项 | P0/P1 | 验收方法 | 证据 | 结果 |
|---|---|---|---|---|---|
| Git | main 分支保护 | P0 | 查看 Ruleset | Ruleset 截图/配置 | |
| Git | PR Review | P0 | 创建测试 PR | PR | |
| Git | CODEOWNERS | P1 | 检查文件 | 文件路径 | |
| Terraform | fmt | P1 | CI 执行 | CI Run | |
| Terraform | validate | P0 | CI 执行 | CI Run | |
| Terraform | Provider 锁定 | P1 | 检查 lock file | `.terraform.lock.hcl` | |
| Security | Secret Scan | P0 | 测试违规输入 | CI Run | |
| Security | Checkov | P1 | CI 执行 | CI Run | |
| Policy | Policy Gate | P0 | 制造违规 Plan | CI Run | |
| State | Remote Backend | P0 | 检查 Backend | Backend 配置 | |
| State | Lock | P0 | 并发测试 | CI / Backend | |
| State | Recovery | P0 | 恢复演练 | Recovery 记录 | |
| IAM | OIDC | P0 | 检查身份链路 | Workflow / Azure | |
| IAM | 最小权限 | P0 | RBAC 审计 | Role Assignment | |
| Change | Production Approval | P0 | 测试绕过路径 | PR / Actions | |
| Resource | Naming / Tag | P1 | Plan / Azure 检查 | Plan / Resource | |
| Operations | Drift Detection | P1 | 制造测试 Drift | CI / Report | |
| Recovery | Apply Failure | P0 | 故障演练 | Runbook Evidence | |
| Recovery | Partial Apply | P0 | 模拟失败 | State + Azure | |
| Recovery | Rollback | P0 | 回滚演练 | Plan / Apply / Verify | |
| Audit | Evidence Chain | P0 | 检查一次完整变更 | PR → CI → Apply | |

---

## 5. CI/CD 验收

标准生产路径：

```text
Pull Request
 ↓
格式检查
 ↓
Validate
 ↓
Lint
 ↓
Security Scan
 ↓
Terraform Plan
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

必须验证：

1. 上一步失败时下一步不会执行。
2. Policy Gate 失败时 Apply 不可执行。
3. Approval 不存在时 Apply 不可执行。
4. 非受控分支不能直接执行生产 Apply。
5. CI 使用短期身份而不是长期 Secret。
6. Apply 使用与 Plan 一致的代码版本和变更上下文。

---

## 6. Policy Gate 验收

不能只检查“Workflow 存在”，必须证明它真的能阻断。

建议至少测试：

```text
故意产生生产 Delete
        ↓
Policy Gate
        ↓
必须 FAIL

故意产生生产 Replace
        ↓
Policy Gate
        ↓
必须 FAIL

故意公网开放高风险端口
        ↓
Policy Gate
        ↓
必须 FAIL
```

每条规则都应该能关联：

```text
Policy ID
 ↓
Rego / Policy 实现
 ↓
Workflow
 ↓
测试输入
 ↓
预期结果
 ↓
实际 CI 结果
```

---

## 7. Plan 验收

Plan 不是“看看有没有报错”，而是生产变更的核心风险证据。

必须识别：

```text
Create
Update
Delete
Replace
```

重点检查：

- Create 是否必要
- Update 是否影响业务
- Delete 是否明确批准
- Replace 是否存在停机/数据风险
- Resource Address 是否变化
- Provider / Module 是否变化
- 是否出现大量非预期变化

---

## 8. State 验收

必须验证：

```text
Remote ✓
Lock ✓
Encryption ✓
Access Control ✓
Recovery ✓
Audit ✓
Environment Isolation ✓
```

### Recovery 演练

不能只写“支持恢复”，必须实际演练：

```text
选择测试 State 版本
 ↓
模拟异常
 ↓
恢复版本
 ↓
读取 State
 ↓
Plan
 ↓
确认资源地址正常
 ↓
确认无异常 Destroy / Replace
```

生产恢复演练应保留证据。

---

## 9. IAM / OIDC 验收

验证：

```text
GitHub Workflow
 ↓
OIDC Token
 ↓
Azure Federated Identity
 ↓
指定身份
 ↓
最小 RBAC
 ↓
目标资源
```

检查：

- 是否存在长期 Client Secret
- Subject / Branch / Environment 是否限制
- Production 身份是否与非生产隔离
- Role Assignment 是否最小化
- 是否存在 Owner / User Access Administrator 等过高权限
- Workflow 是否能被非授权分支复用

---

## 10. Drift 验收

制造一个安全、可恢复的测试 Drift：

```text
Terraform 管理资源
 ↓
人为修改测试属性
 ↓
触发 Plan / Drift Check
 ↓
发现差异
 ↓
判断来源
 ↓
恢复或回写
 ↓
再次 Plan
 ↓
差异消失
```

必须证明 Drift 有发现、判断、处理和关闭路径。

---

## 11. 故障演练

至少覆盖：

- State Locked
- State 异常
- Plan Destroy
- Plan Replace
- Drift
- Apply 失败
- Apply 部分成功
- Provider 升级异常
- Module 变更导致 Replace
- 紧急变更
- Rollback

每次演练记录：

```text
时间
场景
操作人
现象
证据
判断
处理
恢复时间
最终状态
```

---

## 12. 审计证据链

一次完整生产变更必须能串起来：

```text
需求
 ↓
PR
 ↓
Commit SHA
 ↓
CI Run
 ↓
Plan
 ↓
Policy Result
 ↓
Review
 ↓
Approval
 ↓
Apply
 ↓
Verification
 ↓
State Version
```

缺少关键环节时，不能认为审计闭环完整。

---

## 13. 豁免管理

任何 Policy / Security / Approval 豁免必须记录：

- 规则编号
- 资源
- 豁免原因
- 风险
- Owner
- 审批人
- 创建时间
- 到期时间
- 替代控制措施

**没有到期时间的生产豁免默认不合格。**

---

## 14. 最终判定

### PASS

```text
P0 全部通过
+ 核心生产路径验证成功
+ 故障恢复演练成功
+ 审计证据完整
+ 无未解释高风险项
```

### PASS WITH EXCEPTION

允许存在明确记录的低风险问题，但必须同时具备：

- 风险说明
- Owner
- 临时控制措施
- 到期时间
- 后续整改计划

### FAIL

出现任意 P0 阻断项，或者无法证明生产 Apply 的安全边界。

---

## 15. 验收签字

| 角色 | 姓名 | 日期 | 结论 |
|---|---|---|---|
| 实施人 | | | |
| IaC Reviewer | | | |
| 安全负责人 | | | |
| 生产负责人 | | | |

> **Production Ready 不是“文档写完了”，而是关键控制点已经被真实验证，并且每个结论都有证据。**
