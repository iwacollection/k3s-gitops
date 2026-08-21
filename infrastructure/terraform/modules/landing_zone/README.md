# Azure Landing Zone Module

Production Azure foundation module.

Resources covered:

- Resource Group
- Virtual Network
- Subnets
- NSG
- Route Tables
- NAT Gateway
- Private Endpoint
- Identity
- Monitoring
- AKS dependencies
- Database dependencies

Deployment flow:

```
GitHub Actions
    |
Azure OIDC
    |
Terraform Plan
    |
Risk Gate
    |
Approval
    |
Terraform Apply
```

This module is designed for existing resource adoption and new environment provisioning.
