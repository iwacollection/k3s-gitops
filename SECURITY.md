# Security Policy

## Scope

This repository controls production Azure infrastructure. Treat changes under `infrastructure/terraform/**` and `.github/workflows/**` as privileged production changes.

## Reporting

Do not open a public issue containing credentials, Terraform state, access keys, kubeconfig content, database passwords, tokens, or other secrets. Revoke/rotate exposed credentials first, then use a private maintainer channel to coordinate cleanup.

## IaC security rules

- The only active Terraform root is `infrastructure/terraform/environments/production`.
- Never commit Terraform state, saved plans, generated backend files, `.env` files, kubeconfigs, certificates, private keys, or real `tfvars` containing secrets.
- Authenticate GitHub Actions to Azure with OIDC/workload federation; do not add long-lived Azure client secrets.
- Production changes must be reviewed through pull requests.
- A validation-only PR job must never be described as a production plan unless it reads the authoritative remote state.
- Production apply must plan against remote state immediately before apply and reject destructive/replacement actions unless explicitly approved as a migration.
- Do not weaken private networking, RBAC, purge protection, Defender, diagnostics, backup, or availability controls merely to make an apply pass.
- Irreversible controls (for example locked backup immutability) require a dedicated migration decision and rollback analysis before enabling.
- Treat provider/action upgrades as supply-chain changes and review them independently from resource topology changes where practical.

## Incident response for leaked IaC secrets

1. Revoke or rotate the credential at its source.
2. Stop affected workflows if the leaked credential can mutate production.
3. Remove the secret from the current tree and repository history when necessary.
4. Review Azure Activity Logs and GitHub Actions runs for unexpected use.
5. Restore access using OIDC or a least-privilege replacement identity.
6. Document the root cause and add a guard preventing recurrence.
