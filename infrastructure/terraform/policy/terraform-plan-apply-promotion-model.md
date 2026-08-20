# Terraform Plan Apply Promotion Model

## Goal

Production Terraform must apply the reviewed plan artifact, not regenerate a new plan during apply.

## Flow

```text
Pull Request
    |
terraform plan -out=tfplan
    |
terraform show -json tfplan
    |
Risk Gate
    |
Approval
    |
terraform apply tfplan
```

## Risks prevented

- Code changed after approval
- Different plan generated during apply
- Unexpected destroy/replace
- Unreviewed production drift

## Production rule

The reviewed Terraform plan is the source of truth for apply.
