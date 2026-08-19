# IaC Delivery Capabilities

| Capability | Catalog | Runtime | Billing | Status |
|---|---|---|---|---|
| VNet + Subnet | `network/v1` | standard Apply | no paid add-on | live E2E proven |
| Managed Identity | `managed-identity/v1` | standard Apply | no workload charge | live E2E proven |
| IAM Role Binding | `iam-role-binding/v1` | dedicated IAM Apply | none | catalog/plan ready; protected activation required |
| Standard Load Balancer | `load-balancer/v1` | dedicated Edge Apply | billable | catalog/plan ready; protected activation required |
| VPN Gateway foundation | `vpn-gateway/v1` | dedicated Edge Apply | billable | catalog/plan ready; protected activation required |
| VPN S2S Connection | future `vpn-site-connection/v1` | secret-backed Edge Apply | billable | intentionally blocked until PSK secret injection is configured |

## Delivery contract

Every active service must provide a versioned request schema, policy, defaults, renderer, Terraform root stack, remote-state key, PR Plan evidence, exact saved-plan Apply path, post-apply verification, drift detection and governed decommission.

High-risk capabilities use separate OIDC identities/environments rather than expanding the normal Apply identity to broad `Contributor`, `Network Contributor` or unrestricted RBAC write.
