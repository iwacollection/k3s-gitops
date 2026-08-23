# 企业级 IaC（基础设施即代码）管理规范

## 1. 仓库定位

本仓库只负责基础设施生命周期管理，不负责应用代码发布。

负责范围：

- Azure 云资源
- Kubernetes 集群基础设施
- 网络、安全、权限、监控基础能力
- Terraform 状态管理

不负责：

- Docker 镜像构建
- 应用 CI/CD
- 应用 Helm Chart
- 业务服务发布

## 2. 运维负责人管理原则

基础设施必须满足：

1. 所有生产资源必须可追踪
2. 所有变更必须代码化
3. 所有变更必须经过 Plan 审核
4. 禁止直接 Portal 修改生产资源
5. 已有资源必须先接管，再管理

## 3. 新资源创建流程

需求提出

↓

Terraform Module 设计

↓

terraform plan

↓

人工审核资源变化

↓

terraform apply

↓

资源验证

↓

文档更新

## 4. 生产资源保护原则

禁止：

- 覆盖已有资源
- 重建生产资源
- 删除未知资源
- 修改未纳管资源

新增资源必须明确：

- Resource Group
- 命名规范
- Tag
- Owner
- 环境(dev/staging/prod)
