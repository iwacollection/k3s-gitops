# Terraform Production Safety Gate

## Goal

Prevent accidental deletion or recreation of existing production resources.

## Flow

```
terraform plan
        |
        v
terraform show -json
        |
        v
plan-risk-analyzer
        |
        +-- delete detected -> block
        +-- replace detected -> block
        +-- safe update -> continue
```

## Production Rule

- Existing Azure resources must be imported first.
- Destroy requires explicit review.
- Replace requires explicit review.
- Apply should use the reviewed plan artifact.
