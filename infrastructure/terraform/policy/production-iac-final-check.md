# Production IaC Final Implementation Checklist

## Mandatory Flow

PR

-> terraform fmt

-> terraform validate

-> terraform plan artifact

-> destroy/replace risk check

-> production approval

-> terraform apply same plan

## Existing Azure Resource

Never recreate existing resources.

Required:

1. Discover resource
2. terraform import
3. terraform plan
4. Confirm no destroy/replace
5. Enable Terraform management

## Protected Resources

- Resource Group
- Virtual Network
- Subnet
- AKS
- Key Vault
- Storage Account
- Managed Identity

Required controls:

- lifecycle prevent_destroy
- Azure CanNotDelete lock
- Remote state locking
