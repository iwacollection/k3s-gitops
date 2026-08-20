# Request-Driven Terraform Standard

## Purpose

Normal application infrastructure changes are request-driven, not HCL-driven.

Application teams select a platform-approved service and submit only approved input variables. Platform/SRE owns Terraform implementation, provider/module versions, defaults, policy and production safety controls.

## Standard workflow

```text
1. Select catalog service/version
2. Copy request example
3. Fill approved business inputs
4. Open Pull Request
5. Validate request schema
6. Validate environment policy and ownership
7. Render Terraform inputs
8. Run terraform init/validate/plan using Plan Identity
9. Publish plan for review
10. Required reviewers approve
11. Merge request
12. Protected environment checks run
13. Acquire exclusive environment/state lock
14. Apply saved/reproducible plan using Apply Identity
15. Run post-apply verification
16. Record resource/request/commit/plan/apply audit linkage
```

## Developer boundary

Developers may normally change:

- `enterprise-cicd/iac-requests/<environment>/*.json`
- application code and application-owned deployment configuration

Developers may not normally change:

- Terraform provider versions
- platform Terraform modules
- platform root stacks
- state backend definitions
- production service connections/identities
- production approval/check configuration

## Platform boundary

Platform/SRE owns:

- catalog schemas and versions
- Terraform modules/root stacks
- safe defaults
- Azure Policy/RBAC integration
- environment-specific policy limits
- Plan/Apply identities
- state layout
- Required Templates and protected environment checks

## Exception path

If the catalog does not expose a needed capability, do not add arbitrary Terraform to an application repository. Open a platform change request. Platform/SRE extends or versions the module and catalog contract, validates it, then application teams consume the new template version.

## Production rule

A merged request is necessary but not sufficient for PROD. Production Apply must still pass protected environment checks and use the dedicated production Apply identity.
