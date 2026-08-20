# Production IaC Risk Remediation Plan

## Goal

Make Terraform safe for real Azure production resource lifecycle management.

## Controls

### Existing Resource Adoption

Existing Azure resources must follow:

1. Inventory resource
2. terraform import
3. terraform plan
4. Verify no unexpected destroy/create
5. Transfer lifecycle ownership

### Replace/Delete Protection

High risk changes require review:

- Resource Group
- Virtual Network
- Subnet
- AKS
- Storage Account
- Key Vault
- Managed Identity

### Plan Promotion

Production apply should execute the reviewed plan artifact:

terraform plan -out=tfplan

approval

terraform apply tfplan

### Validation

Before production apply check:

- destroy actions
- replace actions
- state drift
- IAM changes
- network changes
