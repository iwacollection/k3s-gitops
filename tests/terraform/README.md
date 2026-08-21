# Terraform Module Contract Test

Production Terraform module validation rules:

1. Module structure
- main.tf must exist
- variables and outputs should be explicit

2. Existing resource adoption
- Existing Azure resources must use import workflow
- No delete and recreate migration

3. Change safety
- destroy must be reviewed
- replace must be blocked by CI

4. Deployment flow

PR
-> validate
-> plan
-> risk gate
-> approval
-> apply approved plan
