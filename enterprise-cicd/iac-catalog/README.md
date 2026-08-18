# IaC Service Catalog

This directory is the platform-owned catalog of approved Azure infrastructure products.

Developers do not edit Terraform modules or root stacks for normal infrastructure requests. They submit a request manifest under `enterprise-cicd/iac-requests/<environment>/` using one of the schemas in `services/`.

## Ownership

- Platform/SRE owns Terraform modules, service schemas, defaults, policy limits and provider versions.
- Application teams own request manifests for their workloads.
- CI validates requests and renders approved variables into the corresponding Terraform root stack.
- Apply is executed only by protected environment identities after required review/checks.

## Request lifecycle

```text
Developer request.yaml
        |
        v
Pull Request
        |
        +-- JSON/YAML schema validation
        +-- naming/tagging/policy validation
        +-- environment entitlement validation
        +-- render Terraform inputs
        +-- terraform fmt/validate
        +-- terraform plan with Plan Identity
        |
        v
Human Review / CODEOWNERS
        |
       Merge
        |
        v
Protected Apply Pipeline
        |
        +-- Environment approval/checks
        +-- Exclusive lock
        +-- Apply Identity
        +-- terraform apply saved plan
        +-- post-apply verification
        |
        v
Azure Resource Created
```

## Normal path vs exception path

Normal path: application teams change only request manifests.

Exception path: if a required capability is not exposed by an existing catalog schema, the request becomes a platform change. The Platform/SRE team extends or versions the Terraform module and schema first; application teams still do not bypass the catalog by writing ad-hoc Terraform in an application repository.
