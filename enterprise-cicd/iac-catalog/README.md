# IaC Service Catalog

This directory is the platform-owned catalog of approved Azure infrastructure products.

Developers do not edit Terraform modules or root stacks for normal infrastructure requests. They submit a request manifest under `enterprise-cicd/iac-requests/<environment>/` using one of the schemas in `services/`.

## Ownership

- Platform/SRE owns Terraform modules, service schemas, defaults, policy limits, provider versions and runtime identities.
- Application teams own request manifests for their workloads.
- CI validates every submitted request and renders approved variables into the corresponding Terraform root stack.
- Each active Catalog request owns an isolated remote-state key and, in Catalog v1, must have exclusive ownership of its Azure Resource Group.
- Apply is executed only by protected environment identities after required review/checks.

## Request lifecycle

```text
InfrastructureRequest JSON
        |
        v
Pull Request
        |
        +-- request envelope/schema validation
        +-- catalog policy/default validation
        +-- environment/path validation
        +-- exclusive Resource Group ownership validation
        +-- render Terraform inputs
        +-- root-stack fmt/init/validate
        +-- Entra-only remote-state Terraform Plan
        +-- destructive change rejection
        +-- Plan evidence artifact
        |
        v
Human Review / CODEOWNERS
        |
       Merge
        |
        v
Protected Apply
        |
        +-- dedicated Apply OIDC identity
        +-- merge-time re-plan
        +-- Azure Blob state lock
        +-- exact saved-plan Apply
        +-- Azure + Terraform output verification
        |
        v
Azure Resource Converged
```

## Runtime safety model

```text
Plan identity
  Azure resource plane: Reader
  Terraform state: container-scoped Storage Blob Data Contributor
  Reason: AzureRM backend Lease Blob locking requires blob write data permission.

Apply identity
  Azure resource plane: capability-specific custom roles only
  Terraform state: container-scoped Storage Blob Data Contributor
  Generic Contributor/Owner: forbidden
  RBAC assignment write: forbidden
```

The DEV Apply capability is currently activated only for `managed-identity` and the restricted `network/v1` product. `network/v1` exposes only an RFC1918 VNet and subnet; NAT Gateway, Public IP, peering, VPN/Application Gateway, Private DNS, NSG and route-table creation are not expressible through that request schema.

All root stacks pin `hashicorp/azurerm` to `~> 4.81.0`. CI also validates the complete root-stack inventory so provider constraints cannot silently drift.

## Drift detection

DEV has scheduled and manually invokable drift detection. It re-renders every **active** request against its remote state with the Plan identity and `terraform plan -detailed-exitcode`.

- `0`: desired state and Azure converge.
- `2`: drift or an unapplied desired change exists; the workflow fails and publishes evidence.
- Terraform/Azure errors fail separately.
- Drift detection never runs Apply or automatic remediation.

## Governed decommission

Deleting an `InfrastructureRequest` is **not** a destroy mechanism.

Retirement uses an immutable `DecommissionRequest` tombstone under `enterprise-cicd/iac-decommission/dev/`. The original InfrastructureRequest remains in Git as the historical and deterministic destroy input.

The decommission path requires:

```text
Tombstone PR
  -> typed DESTROY confirmation + change ticket
  -> remote-state destroy-only Plan using Plan identity
  -> Resource Group ownership-tag validation
  -> reject foreign Azure resources not represented by that Terraform state
  -> review / merge
  -> dedicated Apply identity
  -> repeat ownership check
  -> merge-time destroy-only re-plan + state lock
  -> apply exact saved destroy plan
  -> require Terraform state empty
  -> require dedicated Resource Group absent
  -> retain audit evidence
```

Tombstones are append-only. Retired InfrastructureRequests are immutable and excluded from normal drift reconciliation. Direct `terraform destroy` remains forbidden.

## Normal path vs exception path

Normal path: application teams change only request manifests.

Exception path: if a required capability is not exposed by an existing catalog schema, the request becomes a platform change. The Platform/SRE team extends or versions the Terraform module, policy, permissions and schema first; application teams still do not bypass the catalog by writing ad-hoc Terraform in an application repository.
