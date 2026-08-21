# Terraform Existing Resource Adoption

Production resource adoption flow:

1. Discover existing Azure resources.
2. Import resources into Terraform state.
3. Generate plan JSON.
4. Run resource-adoption-check.sh.
5. Require:
   - create = 0
   - destroy = 0
   - replace = 0
6. Apply only approved plans.

This prevents replacing existing production Azure resources during Terraform onboarding.
