# Production Environment

Enterprise Terraform production environment baseline.

Principles:
- Separate state from other environments
- Apply through GitHub Actions approval
- Use OIDC authentication
- Require plan review before apply
