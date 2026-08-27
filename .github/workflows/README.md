# GitHub Actions Workflow Scope

本目录只允许保存 **Terraform / Azure 基础设施生命周期** 相关 Workflow。

## 允许

- Terraform format / validate / lint / security scan
- Production plan / approval / apply
- Azure OIDC authentication
- Terraform plan artifact / integrity verification
- Drift detection
- Disaster recovery
- Azure / AKS infrastructure post-apply verification
- AKS to ACR RBAC verification

## 不允许

- 业务应用镜像 build / push
- 业务 Helm deploy
- 业务 Kubernetes deploy
- 某个业务应用专属的 Ingress / HTTPS 验证
- 只扫描 `helm/**`、`kubernetes/**` 应用目录的 Workflow

应用交付 Workflow 应跟随对应应用仓库。

## 维护原则

新增 Workflow 前先确认：

```text
Terraform/Azure infrastructure lifecycle?
├── yes -> keep here
└── no  -> application/platform delivery repo
```

如果两个 Workflow 承担同一 Plan/Apply 职责，应优先收敛为单一入口或 reusable workflow，避免多个生产入口产生行为漂移。
