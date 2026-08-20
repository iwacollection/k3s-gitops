# Release / CD Service Catalog

CI produces immutable artifacts. CD promotes an existing artifact digest; it does not rebuild application code.

## Rules

- Release identity is an immutable artifact digest plus source/build metadata.
- DEV -> TEST -> PROD promotion reuses the same digest.
- CI has no direct production cluster-admin permission.
- Production changes pass protected environment checks before GitOps desired state is updated.
- Flux is the target AKS reconciliation control plane.
- Rollback selects a previously approved digest; rollback does not rebuild.

## Initial deployment profiles

- `rolling/rolling-v1`
- `canary/canary-v1`
- `blue-green/blue-green-v1`
