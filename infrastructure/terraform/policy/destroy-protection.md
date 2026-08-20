# Terraform Destroy Protection Policy

## Production Rule

生产环境禁止无审批删除资源。

风险场景：

- resource rename
- resource group change
- module refactor
- provider migration

## Required Controls

### 1. lifecycle protection

核心资源必须配置：

```hcl
lifecycle {
  prevent_destroy = true
}
```

### 2. Plan Review

Terraform plan 必须检查：

```
create
update
delete
replace
```

发现：

```
-/+
 destroy
```

必须进入人工审批。

### 3. State Migration

禁止：

```
old resource
      |
      v
new resource
```

必须使用：

- terraform state mv
- terraform import
- migration plan
