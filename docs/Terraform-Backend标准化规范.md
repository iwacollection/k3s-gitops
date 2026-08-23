# Terraform Backend标准化规范

## 目标

Terraform State 是基础设施真实状态记录，生产环境必须集中、安全、可追踪管理。

## 标准方案

Azure Storage Backend：

- Storage Account
- Blob Container
- State文件隔离
- Blob Lease锁机制
- 定期备份

## 环境隔离

禁止多个环境共享State。

推荐：

```
production/state.tfstate
staging/state.tfstate
dev/state.tfstate
```

## 变更流程

```
Terraform代码修改

↓

terraform init

↓

terraform plan

↓

检查destroy/replace

↓

审批

↓

apply
```

## 禁止操作

- 手工删除State
- 多人同时Apply
- Portal修改Terraform管理资源后不同步代码
