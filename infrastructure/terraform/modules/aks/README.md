# AKS Module Production Baseline

## Required Controls

- Existing AKS clusters must be imported before management.
- Changes affecting cluster identity require replace protection review.
- Enable monitoring and diagnostic settings.
- Separate node pool lifecycle from cluster lifecycle where possible.

## Deployment Flow

```
Plan
 |
Risk Gate
 |
Approval
 |
Apply Approved Plan
```
