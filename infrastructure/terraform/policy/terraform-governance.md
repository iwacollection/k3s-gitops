# Terraform Governance Baseline

## Required Gates

- terraform fmt
- terraform validate
- terraform plan review
- security scanning
- approved apply

## State Management

Terraform state must use remote backend with RBAC authentication.

## Identity

CI/CD authentication uses workload identity federation instead of static secrets.
