# Catalog Service Template

Every catalog service MUST use this shape before it can be offered to application teams:

```text
services/<service>/v1/
├── catalog.json          # module mapping, owner and lifecycle metadata
├── request.schema.json   # fields application teams are allowed to request
├── defaults.json         # platform-owned safe defaults
├── policy.json           # environment limits and forbidden combinations
├── request.example.json  # copyable developer example
└── README.md             # behavior, inputs, outputs and operational notes
```

Rules:

1. Application teams change request manifests, not Terraform HCL.
2. `additionalProperties` should be false for request schemas so unapproved inputs fail closed.
3. Production-safe defaults belong in the catalog, not in application repositories.
4. Provider/module versions are platform-owned and versioned.
5. A breaking interface change creates a new catalog version (`v2`), not an in-place incompatible edit.
6. High-risk capabilities require explicit policy/approval gates or are not exposed at all.
7. Every catalog service maps to a tested Terraform module/root-stack implementation.
8. Modules follow the standard Terraform file layout and expose typed/described variables and outputs.
