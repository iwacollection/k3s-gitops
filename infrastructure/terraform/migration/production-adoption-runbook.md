# Production Terraform Adoption Runbook

## Goal

Safely import existing Azure resources into Terraform without destroy/recreate.

## Workflow

1. Inventory existing Azure resources.
2. Create matching Terraform resource blocks.
3. Import existing resources:

```bash
terraform import <address> <azure-resource-id>
```

4. Run:

```bash
terraform plan
```

5. Expected result:

- No destroy
- No replace
- Only expected drift remediation

## Forbidden

Do not rename production resources directly in Terraform.

Bad:

```
resource name change
terraform apply
```

Required:

- terraform state mv
- terraform import
- migration review

## Safety Rules

- Protect critical resources with prevent_destroy.
- Review every delete/replace action.
- Keep Terraform state backed up.
