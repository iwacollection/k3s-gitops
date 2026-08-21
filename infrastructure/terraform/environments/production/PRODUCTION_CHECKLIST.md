# Production Terraform Readiness Checklist

## Before Apply

- Terraform version verified
- Provider versions locked
- Backend configured
- Existing Azure resources imported when applicable
- Plan reviewed
- Destroy actions reviewed
- Replace actions reviewed

## Apply Rules

- Use approved plan artifact
- Use production approval gate
- Use OIDC authentication
- Do not recreate existing production resources

## After Apply

- Validate Terraform state
- Validate Azure resources
- Run drift detection
- Record change evidence
