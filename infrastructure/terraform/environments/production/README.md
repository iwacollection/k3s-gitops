# Production Terraform Environment

Production environment is the only entry point for production Azure changes.

## Workflow

```
Existing Azure Resource
        |
        v
terraform import
        |
terraform plan
        |
Risk Gate
        |
Approval
        |
terraform apply
```

## Rules

- Never run terraform from repository root for production.
- Existing resources must be imported before management.
- Unexpected destroy and replace actions require explicit review.
- Production state must use remote backend with locking.
