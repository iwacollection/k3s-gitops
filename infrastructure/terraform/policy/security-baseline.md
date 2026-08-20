# Terraform Security Baseline

## Required Checks

- terraform fmt
- terraform validate
- tfsec scan
- checkov scan
- provider version lock
- remote state protection

## Deployment Controls

- GitHub OIDC only
- No static Azure credentials
- Plan before apply
- Production apply requires approval
- Least privilege identity
