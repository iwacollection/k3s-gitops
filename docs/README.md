# 文档中心（中文）

本目录用于维护生产级 Kubernetes、Terraform、Azure IaC（基础设施即代码）治理文档。

## IaC 生产管理

推荐阅读：

- `IaC-Governance-Production-Management.md`

内容包括：

- Terraform 目录设计
- Environment 与 Module 分层管理
- 已有 Azure 资源接入 Terraform 的完整流程
- Terraform State 管理
- GitHub Actions CI/CD 流程
- 权限控制模型
- 防止错误删除、错误重建的安全机制
- Terraform Plan 审核机制
- Policy as Code（策略即代码）治理

## 生产 IaC 标准流程

```text
需求变更
    |
    v
Git Pull Request
    |
    v
Terraform fmt
    |
    v
Terraform validate
    |
    v
TFLint
    |
    v
Checkov 安全扫描
    |
    v
Terraform Plan
    |
    v
策略检查
    |
    v
人工审批
    |
    v
Terraform Apply
    |
    v
生产验证
```

## 文档规范

所有设计说明文档要求：

- 使用中文描述
- 首次出现英文缩写提供中文解释
- 包含生产场景说明
- 包含风险控制方案
- 包含故障恢复方案

