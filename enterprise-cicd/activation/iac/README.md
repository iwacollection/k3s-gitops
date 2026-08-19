# DEV IaC Control-Plane Activation

This directory activates the runtime prerequisites that cannot safely bootstrap themselves through the normal application IaC request path.

## Why this exists

The normal developer path is intentionally unprivileged:

```text
InfrastructureRequest
  -> schema/policy
  -> Terraform Plan identity
  -> review
  -> Terraform Apply identity
  -> verification
```

The existing application/CI GitHub OIDC identity MUST NOT be promoted to subscription `Contributor` merely to make Terraform Apply work.

A one-time privileged Azure bootstrap operator creates:

- `rg-platform-cicd`
- an Entra-only Azure Blob Terraform state backend
- a dedicated DEV IaC Plan UAMI
- a dedicated DEV IaC Apply UAMI
- separate GitHub OIDC federated credentials
- narrowly scoped RBAC assignments

## GitHub OIDC boundaries

Plan identity subject:

```text
repo:iwacollection/k3s-gitops:environment:iac-dev-plan
```

Apply identity subject:

```text
repo:iwacollection/k3s-gitops:environment:iac-dev-apply
```

The two identities are therefore not interchangeable. Configure the GitHub `iac-dev-apply` Environment with deployment protection/approval and branch restrictions before production use.

## State model

DEV lab state backend:

```text
resource group : rg-platform-cicd
storage account: sttfstatec12c3a3699d8
container      : tfstate
```

The account disables Shared Key access and public blob access. GitHub-hosted runners still need the Storage public endpoint, but blob data access is authorized through Microsoft Entra ID/RBAC.

The storage account uses `Standard_LRS` for this lab to minimize control-plane cost. Azure Blob Storage is not a zero-cost service; the cost for a tiny Terraform state is normally very small but should still be treated as billable platform infrastructure. The test User Assigned Managed Identity itself does not add a workload service charge.

## Permission split

### Plan UAMI

- subscription `Reader`
- state container `Storage Blob Data Reader`
- PR planning uses `terraform plan -lock=false`
- no Azure resource mutation permission
- no state write permission

### Apply UAMI

- custom role `Enterprise IaC Managed Identity DEV Apply`
- custom role only permits Resource Group lifecycle + User Assigned Managed Identity lifecycle and control-plane reads
- state container `Storage Blob Data Contributor`
- no `Owner`
- no generic `Contributor`
- no `Microsoft.Authorization/roleAssignments/write`

This custom Apply role is deliberately service-specific for the first E2E catalog test. Additional catalog products should receive explicit permissions instead of silently expanding this role to `*`.

## Run

Dry-run / inventory only:

```bash
bash enterprise-cicd/activation/iac/bootstrap-dev-iac-control-plane.sh
```

Perform the one-time Azure bootstrap:

```bash
bash enterprise-cicd/activation/iac/bootstrap-dev-iac-control-plane.sh --apply
```

The apply run writes one non-secret result file in the current directory:

```text
dev-iac-control-plane-bootstrap-result.json
```

That file contains the real Plan/Apply `clientId`, `principalId`, resource IDs, GitHub Environment subjects, and tfstate names. Commit those IDs only through the governed runtime binding update; never place credentials/client secrets in the repository.

## Required bootstrap operator privileges

The human/bootstrap identity must be able to create Resource Groups, Storage Accounts, User Assigned Managed Identities, custom role definitions, and role assignments at the subscription scope. Azure custom-role creation requires `Microsoft.Authorization/roleDefinitions/write`; role assignment creation requires `Microsoft.Authorization/roleAssignments/write`.

The bootstrap is intentionally explicit and defaults to no mutation.
