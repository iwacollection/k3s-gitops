# Enterprise Terraform Platform

## Structure

- modules: reusable infrastructure components
- environments: dev/staging/prod stacks
- workflows: GitHub Actions execution path

## Delivery Flow

PR -> fmt -> validate -> plan -> approval -> apply

Authentication uses Azure OIDC workload identity. No static cloud credentials are stored in GitHub secrets.
