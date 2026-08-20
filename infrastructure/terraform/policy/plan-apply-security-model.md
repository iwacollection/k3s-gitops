# Terraform Plan Apply Security Model

## Goal

Production Terraform must apply the exact plan that was reviewed.

## Required flow

```
PR
 |
terraform plan -out=tfplan
 |
upload artifact
 |
risk validation
 |
approval
 |
terraform apply tfplan
```

## Forbidden

- Running a fresh plan during apply
- Applying directly from developer branch
- Bypassing destroy/replacement checks

## Reason

A changed configuration between plan and apply can make the applied infrastructure different from the approved change.
