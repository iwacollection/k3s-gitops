# Production Terraform Apply Runbook

## Mandatory Flow

1. terraform init with remote backend
2. terraform plan
3. terraform plan JSON risk check
4. Review destroy/replace actions
5. Approval
6. Apply the approved plan artifact
7. Verify state and Azure resources

## Existing Resources

Production resources must be adopted:

```
Azure Resource
  -> terraform import
  -> terraform plan
  -> zero unexpected destroy/replace
  -> managed by Terraform
```

## Forbidden

- Direct apply from developer workstation
- Recreating existing resources to match Terraform
- Applying a changed plan without review
