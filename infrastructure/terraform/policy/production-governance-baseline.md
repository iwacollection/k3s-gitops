# Terraform Production Governance Baseline

## Resource Adoption Rule

Existing Azure resources must follow:

```
Discovery
  -> terraform import
  -> terraform plan
  -> review
  -> approved apply
```

## Forbidden Changes

Production changes must block:

- unexpected destroy
- unexpected replace
- removal of identity bindings
- breaking network boundary changes

## Required Controls

- lifecycle prevent_destroy
- Azure Management Lock for critical resources
- Remote backend with state locking
- Provider version pinning
- CI validation before apply

## Deployment Flow

```
Pull Request
    |
terraform fmt
    |
terraform validate
    |
terraform plan
    |
Risk review
    |
Approved apply
```
