# Dev Environment

Enterprise Terraform dev environment entrypoint.

Delivery flow:

1. GitHub Actions authenticates through Azure OIDC.
2. Terraform initializes remote state.
3. Plan is generated and reviewed.
4. Approved apply provisions Azure resources.

Managed resources are composed from reusable modules.
