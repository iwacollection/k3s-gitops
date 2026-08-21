# Production Resource Governance Policy

## Safety Rules

Critical Azure resources must satisfy:

- Terraform `prevent_destroy`
- Azure Management Lock where applicable
- Resource ownership tags
- Environment isolation

## Forbidden Changes Without Approval

- destroy
- replace
- backend migration
- identity removal
- network boundary changes

## Adoption Flow

Existing Azure resource:

```
Discovery
  -> terraform import
  -> terraform plan
  -> adoption gate
  -> apply
```

Expected plan for adoption:

```
create = 0
destroy = 0
replace = 0
```
