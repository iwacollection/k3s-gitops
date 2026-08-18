# CI Build Service Catalog

Platform/SRE owns CI profiles. Application teams declare an application definition and select a profile; normal application repositories do not implement their own full CI pipeline.

## Flow

```text
application.yaml
    -> schema/profile validation
    -> reusable CI profile
    -> isolated build environment
    -> dependency proxy/cache policy
    -> test/quality/security
    -> immutable artifact
    -> SBOM/signature/provenance
    -> ACR/package registry
```

## Platform rules

- Build profiles are versioned.
- Build environments are versioned images; mutable long-lived build hosts are not the source of truth.
- CI identity may publish artifacts but must not have production AKS admin or production Terraform apply permission.
- Artifact identity is commit/digest based; `latest` is not a promotion contract.
- Build once, promote the same digest.
- Security and supply-chain controls are profile-owned, not optional project YAML snippets.

## Initial profiles

- `java/springboot-maven-v1`
- `python/python-uv-v1`
- `go/go-service-v1`
- `cpp/cmake-conan-v1`
