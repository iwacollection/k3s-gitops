# Terraform State Recovery Runbook

## Purpose

Protect production Terraform state and provide recovery steps.

## Production requirements

```
Remote Backend
    +
State Locking
    +
Versioning
    +
Backup Recovery
```

## Recovery flow

1. Stop Terraform writes.
2. Identify latest valid state version.
3. Restore state backup/version.
4. Run terraform plan.
5. Validate no unexpected destroy or replace.
6. Resume approved changes.

## Rules

- Never manually replace production state without review.
- Always keep backend state history enabled.
- Verify state against cloud reality after recovery.
