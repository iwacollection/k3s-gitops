# Azure资源命名与Tag管理规范

## 1. 目标

统一 Azure 云资源命名、标签管理方式，保证生产环境资源可识别、可追踪、可审计。

## 2. 命名原则

资源命名格式：

```
环境-资源类型-地域-序号
```

示例：

```
prod-aks-eastasia-001
prod-vnet-eastasia-001
prod-acr-eastasia-001
```

## 3. 环境规范

| 环境 | 标识 |
|-|-|
| 开发环境 | dev |
| 测试环境 | test |
| 预生产 | staging |
| 生产环境 | prod |

## 4. Tag规范

所有 Terraform 管理资源必须包含：

```yaml
Environment: production
ManagedBy: Terraform
Owner: SRE
Application: platform
CostCenter: platform
```

## 5. 资源治理原则

- 禁止创建无Owner资源
- 禁止生产资源缺少Tag
- 禁止通过Portal直接修改Terraform管理资源
- 所有变更必须经过代码审核
