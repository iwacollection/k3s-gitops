# Terraform Policy Gate规范

## 目标

在Terraform Plan阶段阻止高风险基础设施变更。

## 禁止规则

### 公网暴露

禁止：

- Storage Account直接公网访问
- Database公网Endpoint
- AKS API Server无控制访问
- NSG开放任意来源高风险端口

### RBAC权限

禁止：

- Owner权限大范围授权
- Contributor分配给普通用户
- 通配角色授权

### Tag治理

所有生产资源必须包含：

- Environment
- Owner
- ManagedBy
- CostCenter

## 执行位置

Pull Request阶段：

terraform fmt

terraform validate

terraform plan

Policy Scan

失败禁止Merge。