# Terraform 生产 Pipeline 设计

## 目标

本仓库只保留一条 Terraform 生产发布主链：

```text
Pull Request
    |
    v
Validate + Security Gate
    |
    v
Merge main
    |
    v
Production Plan (remote state)
    |
    +--> Destructive Change Gate
    |
    +--> Immutable Plan Artifact + SHA256 + Commit Metadata
    |
    v
production-apply-approval
    |
    v
Apply SAME Plan
    |
    v
Azure / AKS Verification
    |
    v
Post-Apply Drift Check
```

定时 Drift Detection 也由同一个 `terraform-production.yml` 承担；灾难恢复仍保留独立的 `terraform-disaster-recovery.yml`，因为 DR 不是日常发布入口。

## 唯一生产入口

```text
.github/workflows/terraform-production.yml
```

Terraform Root：

```text
infrastructure/terraform/environments/production
```

其他 Terraform Plan / Apply / Policy / Security / Drift 工作流不再作为独立入口存在。

## PR 阶段

PR 阶段不获取 Azure 生产身份，只执行：

- 禁止根目录 Terraform 文件
- 禁止提交 tfstate / tfplan / kubeconfig / key / tfvars 等敏感产物
- Shell 语法检查
- `terraform fmt`
- `terraform init -backend=false`
- `terraform validate`
- Checkov IaC 安全扫描

PR 阶段不生成真实生产 Plan，避免向 PR 暴露生产 OIDC 身份和远程 State。

## Production Plan

合并到 `main` 后或手工执行 Workflow 时：

1. Azure OIDC 登录。
2. 使用现有 `backend.tf` 连接 AzureRM Remote State。
3. 不自动创建第二份 backend 配置。
4. 不执行 `terraform apply -target`。
5. 不自动 import 已有资源。
6. 生成生产 `tfplan`。
7. 转换 JSON 仅用于运行时 destructive gate，不上传 JSON。
8. 如果发现 delete / replacement，标准发布链直接阻断。
9. 仅上传执行所需二进制 Plan、SHA256、commit/run metadata。
10. Artifact 保留 1 天。

> Terraform Saved Plan 可能包含敏感值，因此 Artifact 访问权限必须跟随仓库权限严格控制。

## Apply

Apply Job 必须：

- `needs: plan`
- 使用 `production-apply-approval` Environment
- 下载本次 Run 生成的 Plan Artifact
- 校验 Commit SHA
- 校验 Run ID
- 校验 SHA256
- 再次连接同一个 Remote State
- Apply 同一份 Saved Plan

禁止重新执行新的 Plan 后直接 Apply，从而避免：

```text
Review 的 Plan != 实际 Apply 的 Plan
```

## Quota

AKS 配额恢复属于生产变更前置操作。

日常 Plan 不允许为此提前执行 `terraform apply -target`。

生产 Apply 通过审批后，允许使用独立 Quota OIDC Identity 执行现有 `ensure-aks-quota.sh`，然后重新切回 Apply Identity，再 Apply 已审批 Plan。

前提：

```text
azurerm_role_assignment.quota_request_operator
```

已经由 Terraform State 纳管。如果该前提不存在，应通过 bootstrap / recovery 流程完成一次性接管，而不是在每次发布中提前修改 State。

## Post Apply Verification

Apply 成功后至少验证：VNet、NSG、NAT Gateway、AKS、system/workload Node Pool、Load Balancer、Redis、PostgreSQL、Log Analytics、ACR、Key Vault、AKS Kubelet 到 ACR 的 `AcrPull`，以及 Kubernetes Node Ready。

随后执行：

```text
terraform plan -refresh-only -detailed-exitcode
```

返回：

```text
0 = 无漂移
2 = 有漂移，Pipeline 失败
其他 = Terraform 执行异常
```

注意不能在 `set -e` 下直接执行 `-detailed-exitcode` 后再取 `$?`，否则 exit code 2 会提前退出 Shell。

## Scheduled Drift

每天 UTC 02:00 由同一个主 Workflow 执行 refresh-only drift detection。发现 Drift 时自动创建 GitHub Issue，不自动修复生产资源。

## GitHub 仓库侧必须配置

代码无法替代 Repository / Environment Governance。

### main Branch Protection

至少启用：

- Require a pull request before merging
- Require status checks to pass
- Require branch to be up to date
- Restrict force pushes
- Restrict deletions

Required Check 应包含：

```text
Validate and Security Gate
```

### production-apply-approval Environment

必须配置 Required reviewers，并禁止普通开发者绕过审批。生产 Secret / OIDC Identity 应只存在于受控 Repository Secret 或受保护 Environment。

### production-plan

用于生产 Plan 身份边界。

### production-verification

用于 Apply 后 Azure / AKS 验证和 Scheduled Drift。

## 保留的辅助 Workflow

以下不属于第二条发布链：

```text
terraform-disaster-recovery.yml
    -> 手工 DR / State Recovery

aks-acr-rbac-verification.yml
    -> 基础设施 RBAC 独立验收

enterprise-security-governance.yml
    -> 仓库级供应链 / Secret / SBOM 安全治理
```

应用级 Helm / Kubernetes Workflow 应由应用仓库负责。
