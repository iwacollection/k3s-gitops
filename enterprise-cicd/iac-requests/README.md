# Infrastructure Request Developer Guide

Application teams request Azure infrastructure by committing JSON manifests here. Normal consumers do **not** edit Terraform modules, root stacks, provider configuration, remote-state configuration or GitHub OIDC identities.

## Where to submit

```text
enterprise-cicd/iac-requests/
├── dev/
├── test/
└── prod/
```

The directory and `spec.environment` must match. A request is rejected when they differ.

## Supported V1 products

| Service | Purpose | PR Plan | Apply plane | Cost / risk notes |
|---|---|---|---|---|
| `network` | RFC1918 VNet + Subnet | Real Azure OIDC + remote-state Plan | standard network capability | VNet/Subnet-only product; NAT/Public IP/Peering/VPN are not expressible |
| `managed-identity` | User Assigned Managed Identity | Real Azure OIDC + remote-state Plan | standard Apply identity | low-risk identity resource |
| `iam-role-binding` | Allowlisted RBAC binding to a ServicePrincipal | Real Azure OIDC + remote-state Plan | dedicated conditioned IAM identity | Owner/Contributor/UAA and subscription-root targets are rejected |
| `load-balancer` | Azure Standard Load Balancer | Real Azure OIDC + remote-state Plan | dedicated Edge identity | billable; protected Apply requires explicit confirmation |
| `vpn-gateway` | Route-based Azure VPN Gateway foundation | Real Azure OIDC + remote-state Plan | dedicated Edge identity | billable; V1 deliberately excludes VPN Connection/PSK |
| `acr` | Azure Container Registry | governed renderer + root stack | protected standard runtime | use Catalog policy for SKU/network choices |
| `storage` | Storage Account foundation | governed renderer + root stack | protected standard runtime | private/network policy controlled by Catalog |
| `key-vault` | Key Vault foundation | governed renderer + root stack | protected standard runtime | private-network controls are platform-owned |
| `service-bus` | Service Bus | governed renderer + root stack | protected standard runtime | production policy controls SKU/networking |
| `managed-redis` | Azure Managed Redis | governed renderer + root stack | protected standard runtime | billable service |
| `postgresql-flexible` | PostgreSQL Flexible Server | governed renderer + root stack | protected standard runtime | PROD remains policy-gated until required Entra DBA binding exists |

`network`, `managed-identity`, `iam-role-binding`, `load-balancer`, and `vpn-gateway` are the V1 delivery reference products. Every delivery reference product is required to pass a real Terraform Plan against Azure using the dedicated Plan OIDC identity and Entra-only remote state before its Catalog implementation can be merged.

## Request examples

Use the versioned example belonging to the service. Do not copy Terraform HCL.

```text
enterprise-cicd/iac-catalog/services/network/v1/request.example.json
enterprise-cicd/iac-catalog/services/managed-identity/v1/request.example.json
enterprise-cicd/iac-catalog/services/iam-role-binding/v1/request.example.json
enterprise-cicd/iac-catalog/services/load-balancer/v1/request.example.json
enterprise-cicd/iac-catalog/services/vpn-gateway/v1/request.example.json
```

Minimal request envelope:

```json
{
  "apiVersion": "platform.iac/v1",
  "kind": "InfrastructureRequest",
  "metadata": {
    "name": "payments-network",
    "owner": "payments",
    "application": "payments"
  },
  "spec": {
    "environment": "dev",
    "region": "eastus",
    "service": "network",
    "templateVersion": "v1",
    "parameters": {}
  }
}
```

Fill `parameters` only with fields defined by the service schema and policy. Unknown fields are rejected.

## What happens after a PR is opened

```text
InfrastructureRequest
  -> schema + policy validation
  -> environment/path validation
  -> Catalog renderer
  -> Terraform root stack
  -> Entra-only remote backend
  -> Terraform init + validate
  -> real Terraform Plan
  -> destructive change rejection
  -> Plan evidence artifact
  -> review / approval
  -> protected Apply identity
  -> merge-time re-plan + state lock
  -> exact saved-plan Apply
  -> Azure / Terraform verification
```

The PR Plan identity has Azure resource-plane **Reader** only. It has container-scoped `Storage Blob Data Contributor` solely because the AzureRM backend needs blob lease access for state locking. It cannot create Azure resources.

## High-risk product boundaries

### IAM

`iam-role-binding/v1` is deliberately narrow:

- target principal type: `ServicePrincipal` only;
- target scope: Resource Group or child resource only;
- subscription-root and authorization-resource targets are rejected;
- approved roles only: `Reader`, `AcrPull`, `Storage Blob Data Reader`, `Key Vault Secrets User`;
- `Owner`, `Contributor`, `User Access Administrator`, arbitrary custom roles and arbitrary role-assignment access are rejected.

### Load Balancer / VPN Gateway

These use a dedicated Edge Apply identity rather than the standard Apply identity.

The Edge role does not grant generic `Network Contributor` and does not permit VNet peering, NAT Gateway, Application Gateway, VPN Connection or RBAC writes.

`vpn-gateway/v1` creates the gateway foundation only. A site-to-site shared key / PSK must never be committed to an InfrastructureRequest. A future VPN Connection product must obtain secrets from a protected secret provider rather than Git.

## Changes and deletion

Updating a request creates a new Terraform Plan against its existing isolated remote-state key.

Deleting an InfrastructureRequest is **not** a destroy mechanism. Use the governed `DecommissionRequest` flow. Direct `terraform destroy` and request-deletion-driven auto-destroy are forbidden.

## When a product is missing

Do not add ad-hoc Terraform to an application directory. Open a platform change to introduce or version a Catalog product first. Platform/SRE owns the module, schema, policy, permissions, Plan contract and Apply capability; application teams continue to submit only InfrastructureRequests.
