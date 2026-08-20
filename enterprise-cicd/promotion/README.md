# Promotion Control Plane

Promotion decides whether an already-built immutable artifact may enter the next environment.

## Default path

```text
build -> dev -> test -> prod
```

## Required invariants

- No rebuild during promotion.
- Digest must be identical across promoted environments.
- PROD requires protected environment checks and approval.
- Promotion must record source commit, build profile, artifact digest, test evidence, approver and target environment.
- Failed verification selects a previous approved digest or slot according to the release profile.

## Boundaries

- `policies/`: environment eligibility and promotion rules.
- `verification/`: health/metric gates after deployment.
- `rollback/`: rollback selection and evidence requirements.
