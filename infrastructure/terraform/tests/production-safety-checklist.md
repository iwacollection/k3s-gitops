# Terraform Production Safety Checklist

## Before Apply

- [ ] terraform fmt passed
- [ ] terraform validate passed
- [ ] terraform plan generated
- [ ] plan JSON risk analysis passed
- [ ] destroy count is 0 unless explicitly approved
- [ ] replace count is 0 unless migration is approved
- [ ] existing resources are imported before management

## Apply Requirements

- [ ] Approved plan artifact is used
- [ ] Production environment approval completed
- [ ] Remote backend lock is healthy
- [ ] Azure identity uses OIDC federation

## After Apply

- [ ] terraform state is consistent
- [ ] Azure resources match expected configuration
- [ ] No unexpected drift detected
