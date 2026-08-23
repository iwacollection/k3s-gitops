# Terraform代码扫描规范

## 检查目标

确保IaC代码符合生产安全要求。

## 基础检查

```
terraform fmt
terraform validate
terraform plan
```

## 安全扫描

检查：

- 明文Secret
- 高风险权限
- 公网暴露资源
- 不安全网络规则
- 未设置Tag资源

## 生产风险检查

重点关注：

- destroy
- replace
- force new resource
- 数据资源变更

## 原则

Terraform不是脚本，而是生产基础设施生命周期管理代码。
