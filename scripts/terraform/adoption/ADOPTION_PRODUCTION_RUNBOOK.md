# Terraform Existing Azure Resource Adoption Production Runbook

## Goal

Safely onboard existing Azure resources into Terraform without destroy/recreate.

## Flow

1. Inventory Azure resources
2. Build Terraform resource mapping
3. Execute terraform import
4. Run terraform plan
5. Validate no destroy or replace
6. Review approval
7. Apply approved plan only

## Forbidden

- terraform destroy on production
- replacing existing immutable resources without review
- applying without reviewed plan artifact

## Validation

Required checks:

- Resource exists in Azure
- Resource exists in Terraform state
- Plan does not contain delete
- Plan does not contain replace
- Drift is reviewed
