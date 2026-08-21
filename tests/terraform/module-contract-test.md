# Terraform Module Contract Test

## Purpose

Validate Terraform modules before production usage.

## Required Checks

```text
Module Change
    |
    v
Input Validation
    |
    v
Import Compatibility
    |
    v
Destroy Safety Check
    |
    v
Regression Validation
```

## Production Requirements

- Existing Azure resources must be importable.
- No unexpected destroy actions.
- No unexpected replace actions.
- Variables must have safe defaults or explicit inputs.
- Outputs must expose required operational information.

## Test Scenarios

### Existing Resource Adoption

```text
Azure Resource
 -> terraform import
 -> terraform plan
 -> verify zero destroy
```

### Change Safety

```text
terraform plan json
 -> risk analyzer
 -> destroy guard
 -> replace guard
```
