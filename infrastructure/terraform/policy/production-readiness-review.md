# Production IaC Readiness Review

## Resource Safety

- Existing Azure resources must be imported before management.
- Resource rename must use terraform state migration.
- Critical resources require prevent_destroy.

## Change Safety

Before apply:

1. terraform fmt
2. terraform validate
3. terraform plan
4. inspect delete/replace operations
5. approval before production apply

## Operational Checks

- Remote state enabled
- State locking enabled
- Backup and recovery procedure documented
- Drift detection scheduled
- Ownership defined
