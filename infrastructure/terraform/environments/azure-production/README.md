# Azure Production Environment

Production resource composition.

Expected stack:

```
Resource Group
 |
 +-- VNet
 |    +-- AKS Subnet
 |    +-- Private Endpoint Subnet
 |
 +-- Load Balancer / Application Gateway
 |
 +-- AKS
 |
 +-- PostgreSQL Flexible Server
 |
 +-- ACR
 |
 +-- Key Vault
 |
 +-- Log Analytics
```

Apply requirements:

1. terraform plan
2. Risk analysis
3. Production approval
4. Apply approved plan
5. Verification
