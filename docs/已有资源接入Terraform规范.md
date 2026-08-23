# 已有资源接入 Terraform 管理规范

## 1. 背景

企业通常不是从零创建云资源，而是已有大量 Portal 创建资源，需要逐步纳入 IaC 管理。

目标：

在不影响业务的情况下，将已有资源导入 Terraform。

## 2. 接入原则

禁止：

- 重新 terraform apply 创建同名资源
- 删除旧资源重新创建
- 修改生产资源属性后直接覆盖

必须流程：

现有资源盘点

↓

Terraform Resource 定义

↓

terraform import

↓

terraform plan 差异分析

↓

调整代码匹配真实资源

↓

纳管完成

## 3. 接入步骤

### 第一步：资源发现

收集：

- Azure Resource ID
- Resource Group
- Region
- Tag
- 当前配置

### 第二步：编写 Terraform

先创建资源声明：

```hcl
resource "azurerm_xxx" "existing" {
}
```

不要立即 apply。

### 第三步：导入 State

```bash
terraform import resource.address resource_id
```

### 第四步：验证漂移

执行：

```bash
terraform plan
```

目标：

No changes

## 4. 大规模接入策略

按照优先级：

1. 网络
2. AKS
3. ACR
4. 数据库
5. 安全资源
6. 监控资源

逐步迁移，禁止一次性重构整个生产环境。
