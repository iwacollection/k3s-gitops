# Azure RBAC Governance Baseline

## Production principle

Terraform CI/CD should not use subscription Owner permissions by default.

Recommended split:

```
Plan stage
  -> Reader + Terraform state access

Apply stage
  -> Scoped deployment permissions
     Resource Group / Management Group level
```

## Permission model

- Read-only audit identity: inventory and drift analysis
- Terraform deployer identity: controlled apply permissions
- Human approval: production change authorization

## Security requirements

- Use GitHub Actions OIDC federation
- Avoid long-lived Azure client secrets
- Apply least privilege RBAC
- Separate non-production and production identities
