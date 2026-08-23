# Terraform环境隔离规范

## 1. 目标

避免开发、测试、生产环境互相影响，降低误操作风险。

## 2. 目录结构

```text
terraform/

├── modules/
│
├── environments/
│   ├── dev/
│   ├── staging/
│   └── production/
```

## 3. State隔离

每个环境必须独立State：

```text
terraform-state-dev
terraform-state-staging
terraform-state-production
```

禁止多个环境共享State。

## 4. Subscription隔离

生产环境必须使用独立Azure Subscription或明确隔离的资源组。

## 5. 变量隔离

示例：

```
environments/production/terraform.tfvars
```

保存生产环境：

- SKU
- 网络配置
- 节点数量
- 高可用参数

## 6. 生产保护

生产Apply必须经过：

```
terraform fmt

terraform validate

terraform plan

人工审核

terraform apply
```
