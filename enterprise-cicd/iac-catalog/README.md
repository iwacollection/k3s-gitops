# IaC Service Catalog

This directory is the platform-owned catalog of approved Azure infrastructure products.

Developers do not edit Terraform modules or root stacks for normal infrastructure requests. They submit a request manifest under `enterprise-cicd/iac-requests/<environment>/` using one of the versioned schemas in `services/`.

Developer usage is documented in `enterprise-cicd/iac-requests/README.md`.

## Ownership

- Platform/SRE owns Terraform modules, service schemas, defaults, policies, provider versions, remote state and runtime identities.
- Application teams own InfrastructureRequest manifests for their workloads.
- CI validates every submitted request and renders approved variables into the corresponding Terraform root stack.
- Each active Catalog request owns an isolated remote-state key and, in Catalog v1, must have exclusive ownership of its Azure Resource Group.
- Apply is executed only by protected capability identities after the required review/checks.

## V1 delivery reference products

The V1 delivery baseline is not satisfied by `terraform validate` alone. Every reference product below must have a real Azure OIDC + Entra-only remote-state Terraform Plan gate.

| Product | Catalog | Real Plan | Apply model |
|---|---|---:|---|
| VNet + Subnet | `network/v1` | yes | standard network capability |
| User Assigned Managed Identity | `managed-identity/v1` | yes | standard Apply identity |
| IAM Role Binding | `iam-role-binding/v1` | yes | dedicated conditioned IAM identity |
| Standard Load Balancer | `load-balancer/v1` | yes | dedicated Edge identity + billable confirmation |
| VPN Gateway foundation | `vpn-gateway/v1` | yes | dedicated Edge identity + billable confirmation |

Managed Identity and VNet/Subnet have already completed real Azure Apply E2E and converged remote state. IAM/LB/VPN are delivery-ready only when their dedicated protected Apply capability is activated for the target environment.

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
        +-- dedicated capability Apply OIDC identity
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

Standard Apply identity
  Low-risk platform products only
  Generic Contributor/Owner: forbidden

Network Foundation Apply capability
  VNet/Subnet only
  Public IP / NAT / Peering / VPN / Application Gateway: forbidden

Edge Apply capability
  Standard Public IP / Standard Load Balancer / VPN Gateway foundation
  Generic Network Contributor: forbidden
  Peering / NAT / Application Gateway / VPN Connection / RBAC write: forbidden

IAM Apply capability
  Conditioned RBAC Administrator delegation
  Target principal: ServicePrincipal only
  Target roles: explicit low-risk allowlist only
  Owner / Contributor / User Access Administrator / arbitrary role assignment: forbidden

Terraform state
  Entra ID only
  Shared Key access: disabled
```

All root stacks pin `hashicorp/azurerm` to the platform-approved provider line. CI validates the root-stack inventory so provider constraints cannot silently drift.

## Capability activation

The platform activation scripts are intentionally PLAN ONLY by default.

```text
enterprise-cicd/activation/iac/
├── activate-iac-network-foundation-capability.sh
├── activate-iac-edge-network-capability.sh
├── activate-iac-iam-capability.sh
└── activate-iac-delivery-capabilities.sh
```

The unified delivery entry point plans or activates the dedicated Edge and IAM Apply planes for `dev`, `test` or `prod`:

```bash
bash enterprise-cicd/activation/iac/activate-iac-delivery-capabilities.sh --environment dev
bash enterprise-cicd/activation/iac/activate-iac-delivery-capabilities.sh --environment dev --apply
```

The second command is privileged Azure mutation and must be run only by an authorized bootstrap operator. It emits one combined non-secret result JSON that is used to update the governed runtime binding.

## Drift detection

Scheduled/manual drift detection re-renders active requests against remote state using the Plan identity and `terraform plan -detailed-exitcode`.

- `0`: desired state and Azure converge.
- `2`: drift or unapplied desired change exists; the workflow fails and publishes evidence.
- Terraform/Azure errors fail separately.
- Drift detection never applies automatic remediation.

## Governed decommission

Deleting an InfrastructureRequest is **not** a destroy mechanism.

Retirement uses an immutable `DecommissionRequest` tombstone. The original InfrastructureRequest remains in Git as the historical deterministic destroy input.

```text
Tombstone PR
  -> typed DESTROY confirmation + change ticket
  -> remote-state destroy-only Plan using Plan identity
  -> Resource Group ownership-tag validation
  -> reject foreign Azure resources not represented by Terraform state
  -> review / merge
  -> dedicated Apply identity
  -> repeat ownership check
  -> merge-time destroy-only re-plan + state lock
  -> apply exact saved destroy plan
  -> require Terraform state empty
  -> require dedicated Resource Group absent
  -> retain audit evidence
```

Tombstones are append-only. Direct `terraform destroy` remains forbidden.

## Normal path vs exception path

Normal path: application teams change only request manifests.

Exception path: if a required capability is not exposed by an existing catalog schema, it becomes a platform change. Platform/SRE extends or versions the Terraform module, policy, permissions, real Plan contract and Apply capability first; application teams still do not bypass the Catalog with ad-hoc Terraform.
