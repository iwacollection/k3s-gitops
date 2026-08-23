# Terraform Module治理规范

## Module设计原则

Module负责复用基础设施能力，不绑定具体环境。

标准结构：

```
modules/
├── network/
├── aks/
├── acr/
├── monitoring/
└── identity/
```

## Module要求

必须包含：

- variables.tf 参数定义
- main.tf 资源逻辑
- outputs.tf 输出信息
- versions.tf Provider约束

## 禁止事项

禁止：

- 硬编码订阅ID
- 硬编码密码
- 环境配置混入Module
- 直接引用生产资源名称

## 审计检查

检查：

- resource命名
- tag完整性
- 权限最小化
- destroy风险
- replace风险
