# IaC生产Ready验收报告

## 1. 仓库定位

本仓库定位：

> Azure 基础设施 IaC 管理仓库

负责：

- Terraform资源生命周期管理
- AKS基础设施治理
- Azure网络、身份、安全配置
- 资源漂移检测

不负责：

- 应用镜像构建
- 应用发布
- Helm应用生命周期

---

# 2. Terraform Workflow治理

标准流程：

```
Pull Request
    |
    + terraform fmt
    |
    + terraform validate
    |
    + Security Scan
    |
    + terraform plan
    |
    + Plan Artifact
    |
    + Production Approval
    |
    + terraform apply
```

治理要求：

- Terraform逻辑统一通过Reusable Workflow复用
- 禁止复制多个Apply流程
- 禁止绕过Plan直接Apply

---

# 3. Apply安全控制

生产Apply必须满足：

- GitHub Environment保护
- Approval Gate
- Azure OIDC认证
- 最小权限RBAC

禁止：

- Service Principal长期Secret
- 本地直接terraform apply
- 绕过审批修改生产资源

---

# 4. Azure资源治理

资源接入流程：

```
Azure Existing Resource
        |
        v
资源盘点
        |
        v
Terraform Resource定义
        |
        v
terraform import
        |
        v
terraform plan校准
```

禁止直接重新创建已有生产资源。

---

# 5. 生产验收清单

## Terraform

- [ ] fmt通过
- [ ] validate通过
- [ ] backend标准化
- [ ] module边界清晰
- [ ] state受保护

## Security

- [ ] 公网暴露检查
- [ ] RBAC最小权限
- [ ] Tag治理
- [ ] Secret扫描

## Operations

- [ ] Drift Detection
- [ ] Apply后验证
- [ ] 变更可审计

---

# 6. 运维使用原则

任何Azure资源变更必须遵循：

```
发现需求
  |
修改Terraform
  |
PR Review
  |
Plan确认
  |
Approval
  |
Apply
  |
验证
```

Terraform代码、Git提交记录、State共同组成生产基础设施审计链路。
