# GitHub Actions CI Plane

Primary role: application CI and artifact production.

Responsibilities:
- PR validation
- build/test/security
- immutable artifact publishing
- OIDC-based Azure access when required

Production Kubernetes desired state will move through GitOps rather than unrestricted kubectl from CI.
