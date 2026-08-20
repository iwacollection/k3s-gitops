# Enterprise IaC Platform

Structure:

- modules: reusable Terraform components
- environments: environment instances

Target lifecycle:

PR -> Terraform Plan -> Approval -> Apply -> Drift Detection

Authentication:

Azure Managed Identity + GitHub OIDC
