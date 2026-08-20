# Terraform Production Go Live Checklist

Before creating or adopting Azure resources:

## State

- Remote backend configured
- Locking enabled
- State ownership defined

## Existing resources

- Resource inventory completed
- Import completed
- terraform plan reviewed
- No unexpected destroy/recreate

## Change safety

- Plan artifact reviewed
- Delete detection enabled
- Approval required for production

## Recovery

- State backup available
- Rollback procedure documented
