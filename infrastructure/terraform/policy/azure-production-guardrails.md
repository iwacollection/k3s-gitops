# Azure Production Guardrails

## Layer 1 Terraform Protection

Use lifecycle protection for critical resources:

```hcl
lifecycle {
  prevent_destroy = true
}
```

## Layer 2 Azure Protection

Use Azure management locks where appropriate:

- CanNotDelete for critical infrastructure
- ReadOnly only when operationally acceptable

## Operational Rules

Never rename production resources directly through Terraform if Azure requires replacement.

Preferred migration:

1. terraform state mv
2. terraform import
3. terraform plan
4. controlled apply

## Environment Isolation

Production should have:

- isolated backend
- isolated state
- controlled approval
- limited permissions
