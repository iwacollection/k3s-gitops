# Terraform Resource Change Risk Rules

## Block Automatically

- destroy of production resources
- replace of critical resources
- unmanaged existing resource creation conflicts
- state changes without review

## Require Review

- resource name changes
- subnet CIDR changes
- AKS configuration changes
- identity permission changes

## Allowed

- tags update
- monitoring configuration updates
- non-breaking configuration changes
