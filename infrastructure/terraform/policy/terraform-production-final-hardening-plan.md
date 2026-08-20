# Terraform Production Final Hardening Plan

## Goal
Prepare k3s-gitops for real Azure production resource lifecycle management.

## Mandatory Controls

### 1. Plan Promotion

Production apply must use the reviewed plan artifact.

```
terraform plan -out=tfplan
        |
        v
risk validation
        |
        v
approval
        |
        v
terraform apply tfplan
```

### 2. Destroy Protection

Critical resources require lifecycle protection:

```hcl
lifecycle {
  prevent_destroy = true
}
```

Apply to:

- Resource Group
- VNet
- Subnet
- AKS
- Storage
- Key Vault
- Identity

### 3. Existing Resource Adoption

Never recreate existing Azure resources.

Correct:

```
Azure Resource
      |
terraform import
      |
terraform plan
      |
terraform manage
```

### 4. Replacement Detection

Block:

- delete
- delete/create replacement
- state mismatch recreation

### 5. State Safety

Require:

- remote backend
- locking
- backup
- ownership

### 6. Production Review

Before apply verify:

- subscription
- resource group
- state
- plan diff
- blast radius
