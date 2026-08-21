# Network Module

## Production Requirements

- Support imported Azure existing resources
- Validate CIDR and naming inputs
- Protect critical network resources
- Export stable outputs for dependent modules

## Adoption Flow

```
Existing Azure VNet
        |
        v
terraform import
        |
        v
terraform plan
        |
        v
Risk validation
```
