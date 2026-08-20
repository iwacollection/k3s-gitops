# Terraform Production Preflight Checklist

## Before first production apply

- [ ] Existing resources imported into Terraform state
- [ ] terraform plan shows no unexpected destroy
- [ ] replace actions reviewed
- [ ] backend state locking enabled
- [ ] resource ownership documented
- [ ] production approval configured

## Critical resources

Review carefully:

- Resource Group
- Virtual Network
- Subnet
- AKS Cluster
- Storage Account
- Key Vault
- Managed Identity

## Migration rule

Do not rename production resources through normal apply.
Use state migration or import workflow.
