# Governed IaC Decommission

Decommission is intentionally separate from normal InfrastructureRequest Apply.

## DEV v1 contract

A resource is retired by **adding** an immutable `DecommissionRequest` under `iac-decommission/dev/`. The original `iac-requests/dev/*.json` file remains in Git as the canonical historical input used to render the exact Terraform state during destroy.

The flow is:

`Tombstone PR -> validation -> remote-state destroy-only Plan -> review -> merge -> dedicated Apply OIDC -> merge-time destroy-only re-plan -> exact saved-plan Apply -> state/Azure absence verification`

Safety boundaries:

- deleting an InfrastructureRequest is not a decommission mechanism;
- tombstones are append-only and immutable;
- retired InfrastructureRequests are immutable and excluded from drift reconciliation;
- DEV v1 only supports capabilities already activated for Apply: `managed-identity` and `network`;
- decommission Plan must contain only `delete` actions and at least one deletion;
- the target resource group must be tagged for the referenced request;
- Azure resources in the target resource group must be represented by the request's Terraform state; foreign resources block deletion;
- Apply uses `iac-dev-apply`, state locking, and the exact saved merge-time destroy plan;
- no direct `terraform destroy` command is used;
- successful Apply must leave the request state empty and the dedicated resource group absent.

Example tombstone:

```json
{
  "apiVersion": "platform.iac/v1",
  "kind": "DecommissionRequest",
  "metadata": {
    "name": "decommission-example",
    "owner": "platform-sre",
    "changeTicket": "CHG-1234",
    "reason": "Example workload has been retired"
  },
  "spec": {
    "environment": "dev",
    "requestPath": "enterprise-cicd/iac-requests/dev/example.json",
    "requestName": "example",
    "service": "managed-identity",
    "confirmation": "DESTROY example"
  }
}
```

Do not create a tombstone as a test unless the referenced Azure resources are intentionally approved for destruction.
