# Terraform State Governance

## Backend requirements

Production Terraform state must have:

- Remote backend
- State locking
- Version history
- Recovery procedure
- Ownership definition

## Rules

Never edit state manually unless performing a documented migration.

Migration examples:

```bash
terraform state mv
terraform import
```

Validation requirement:

```bash
terraform plan
```

Expected result after adoption:

```text
No changes
```
