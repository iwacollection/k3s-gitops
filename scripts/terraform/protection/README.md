# Azure Production Resource Protection

## Purpose

Protect existing production Azure resources from accidental Terraform destruction or replacement.

## Protection layers

1. Terraform lifecycle protection
2. Azure resource locks
3. CI risk gates
4. Manual approval before apply

## Protected resource candidates

- Virtual Network
- Subnet
- AKS Cluster
- Storage Account
- Key Vault
- Database

## Production rule

Existing resources must be imported and verified before Terraform management.

Destroy and replace operations require explicit review.
