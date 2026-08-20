# Terraform Replacement Analysis

## Why replacement is dangerous

Terraform replacement appears as:

```text
-/+

or

["delete", "create"]
```

This can happen because of:

- resource name changes
- immutable Azure properties
- incorrect import
- state mismatch

## Required handling

Before approval:

1. Confirm why replacement happens
2. Check production impact
3. Prefer migration or import
4. Require manual approval for critical resources

Never assume replacement is harmless in production.
