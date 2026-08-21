# Azure Resource Import Automation

## Goal

Safely onboard existing Azure resources into Terraform without delete/recreate.

## Production Flow

```text
Azure Existing Resource
        |
        v
Resource Discovery
        |
        v
Generate terraform import command
        |
        v
terraform import
        |
        v
terraform plan
        |
        v
Validation

Expected:
create=0
unexpected destroy=0
unexpected replace=0
```

## Rules

- Never import directly into production without backup of Terraform state.
- Always review plan after import.
- Any destroy or replace requires explicit approval.
