# Terraform Production Plan Artifact Verification

## Goal

Production apply must execute the exact Terraform plan that passed review.

## Required Flow

```
terraform plan
    |
    v
risk analysis
    |
    v
artifact upload
    |
    v
production approval
    |
    v
terraform apply approved.tfplan
```

## Forbidden

- Running `terraform apply` without approved plan artifact
- Generating a new plan after approval
- Applying from an untrusted workspace

## Verification

After apply:

```
terraform plan -refresh-only
```

must confirm state consistency.
