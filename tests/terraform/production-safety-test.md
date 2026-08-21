# Terraform Production Safety Test

## Purpose

Validate that Terraform changes are safe before production apply.

## Required Checks

1. terraform fmt
2. terraform validate
3. terraform plan JSON generation
4. destroy detection
5. replace detection
6. import compatibility check

## Production Rules

Allowed:

- create
- update
- no-op

Blocked:

- unexpected delete
- resource replacement
- state mismatch

## Existing Resource Adoption

Existing Azure resources must follow:

Azure Resource

-> terraform import

-> terraform plan

-> risk analysis

-> approval

-> apply
