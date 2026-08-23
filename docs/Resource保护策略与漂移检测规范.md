# Resource保护策略与漂移检测规范

## 资源保护目标

避免生产基础设施被误删除或者被Portal手工修改。

## Terraform生命周期保护

关键资源建议增加：

```hcl
lifecycle {
  prevent_destroy = true
}
```

适用：

- AKS
- VNet
- ACR
- Storage Account
- Key Vault

## 资源漂移检测

定义：

Terraform代码、State和Azure实际资源状态不一致。

检测流程：

代码

↓

terraform plan

↓

发现Azure侧变化

↓

人工确认

↓

import或者代码修正

## 禁止操作

- Portal直接修改Terraform管理资源
- 未经过Plan直接Apply
- 删除State文件
