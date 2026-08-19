# DEV Infrastructure Requests

Application teams create or modify only request manifests in this directory for normal DEV infrastructure changes.

Normal lifecycle:

```text
request
  -> PR schema/policy validation
  -> real remote-state Terraform Plan
  -> review
  -> merge
  -> dedicated DEV Apply OIDC
  -> merge-time re-plan + state lock
  -> exact saved-plan Apply
  -> Azure/Terraform verification
```

Rules:

- Do not add `.tf` files here.
- Do not embed credentials, tokens or secrets in requests.
- Do not delete an InfrastructureRequest to remove Azure resources.
- Catalog v1 requires exclusive Resource Group ownership per active request/state.
- A retired request remains in this directory as immutable audit and deterministic destroy input.
- Retirement is requested only by adding an immutable tombstone under `enterprise-cicd/iac-decommission/dev/`.
- Retired requests are excluded from normal drift reconciliation and cannot be edited or deleted.

For destroy/decommission rules, see `enterprise-cicd/iac-decommission/README.md`.
