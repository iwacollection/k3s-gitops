# Production IaC Readiness Checklist

## Resource Adoption

- Existing Azure resources must be imported before management.
- Never use Terraform apply to discover ownership of existing resources.
- `terraform plan` must show no unexpected destroy or replace actions after import.

## Destruction Safety

- Critical Azure resources require `lifecycle.prevent_destroy`.
- Delete or replace operations require explicit review.

## Change Workflow

1. terraform fmt
2. terraform validate
3. terraform plan
4. risk analysis
5. approval
6. terraform apply
7. verification

## Migration

Resource rename must use:

- terraform state mv
- terraform import

Do not rename production resources directly in Terraform configuration.
