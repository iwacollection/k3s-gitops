# Terraform Backend实施规范

## 目标

统一Terraform State管理，避免多人操作造成状态覆盖、资源漂移和误删除。

## Backend标准

生产环境统一使用 Azure Storage Backend：

- Storage Account：Terraform专用存储
- Container：terraform-state
- State文件：按环境隔离

示例：

```
terraform-state/
├── dev/terraform.tfstate
├── staging/terraform.tfstate
└── production/terraform.tfstate
```

## 已有资源接入流程

禁止重新创建已有Azure资源。

流程：

1. Azure查询现有资源
2. 编写Terraform Resource定义
3. terraform import导入State
4. terraform plan确认无变化
5. 纳入日常IaC管理

## 变更原则

任何生产变更必须经过：

代码修改 -> fmt -> validate -> plan -> 审核 -> apply

禁止直接控制台修改生产资源。
