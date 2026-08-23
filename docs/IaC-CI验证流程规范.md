# IaC CI验证流程规范

## 1. 目标

通过自动化检查保证Terraform代码质量，避免错误配置进入生产环境。

## 2. Pull Request流程

```text
开发提交Terraform代码

        ↓

terraform fmt检查

        ↓

terraform validate

        ↓

terraform plan

        ↓

安全扫描

        ↓

人工审核

        ↓

Apply
```

## 3. CI检查项

### 格式检查

```bash
terraform fmt -check
```

保证代码规范。

### 配置验证

```bash
terraform validate
```

检查Terraform语法和模块依赖。

### Plan检查

生成资源变化计划：

重点关注：

- destroy
- replace
- 大规模资源变化

## 4. 安全原则

禁止：

- CI自动删除生产资源
- 未审核直接Apply
- 绕过Terraform修改云资源

## 5. 长期治理

后续增加：

- Checkov
- Terraform安全扫描
- Drift Detection资源漂移检测
- 成本检查
