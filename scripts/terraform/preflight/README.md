# Terraform Production Preflight

Before managing Azure production resources:

1. Verify Terraform CLI
2. Verify Azure CLI authentication
3. Verify subscription context
4. Verify backend configuration
5. Run import validation before apply

Flow:

Azure Subscription

-> Preflight

-> Resource Discovery

-> Terraform Import

-> Terraform Plan

-> Risk Gate

-> Approval

-> Apply approved plan
