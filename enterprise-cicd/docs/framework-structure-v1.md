# Enterprise IaC + CI/CD Framework Structure V1

```text
enterprise-cicd/
├── architecture/                 # control-plane architecture and ownership boundaries
├── contracts/                    # machine-readable environment/state/identity/repository contracts
├── iac-catalog/                  # platform-owned Terraform service catalog
│   ├── request.schema.json       # common infrastructure request envelope
│   └── services/
│       ├── _template/            # mandatory template for every catalog service
│       └── <service>/v1/         # schema/defaults/policy/module mapping/example
├── iac-requests/                 # application-team editable infrastructure requests
│   ├── dev/
│   ├── test/
│   └── prod/
├── ci-catalog/                   # platform-owned build service catalog
│   ├── java/springboot-maven-v1/
│   ├── python/python-uv-v1/
│   ├── go/go-service-v1/
│   └── cpp/cmake-conan-v1/
├── application-definitions/      # app team selects approved CI/release profiles
├── release-catalog/              # platform-owned CD strategy catalog
│   ├── rolling/rolling-v1/
│   ├── canary/canary-v1/
│   └── blue-green/blue-green-v1/
├── release-requests/             # immutable digest promotion requests
├── promotion/
│   ├── policies/                 # DEV -> TEST -> PROD eligibility rules
│   ├── verification/             # post-deploy health/metric gates
│   └── rollback/                 # previous approved digest/slot rules
├── terraform/
│   ├── bootstrap/                # creates only IaC prerequisites
│   ├── state/                    # backend/state-key rendering
│   ├── modules/                  # reusable Terraform modules owned by Platform/SRE
│   │   ├── resource-group/
│   │   ├── managed-identity/
│   │   ├── acr/
│   │   ├── network/
│   │   ├── aks/
│   │   └── workload-base/
│   └── stacks/                   # root modules / state boundaries; not normal developer edit surface
│       ├── platform/
│       │   ├── governance/
│       │   ├── connectivity/
│       │   ├── identity/
│       │   ├── acr/
│       │   └── aks/
│       └── workloads/
│           ├── dev/
│           ├── test/
│           └── prod/
├── azure-devops/
│   ├── templates/
│   │   ├── terraform/
│   │   └── application/
│   ├── pipelines/
│   │   ├── platform/
│   │   └── workload/
│   ├── environments/
│   ├── service-connections/
│   └── agent-pools/
├── github-actions/
│   ├── reusable/
│   └── policies/
├── ci-scripts/
│   ├── common/
│   ├── go/
│   ├── python/
│   ├── java/
│   ├── cpp/
│   └── infra/
├── build-images/
│   ├── base/
│   ├── go/
│   ├── python/
│   ├── java/
│   ├── cpp/
│   └── infra/
├── dependency-proxy/
│   ├── maven/
│   ├── pypi/
│   ├── go/
│   └── cpp/
├── artifacts/
│   ├── acr/
│   ├── packages/
│   └── promotion/
├── gitops/
│   ├── clusters/
│   ├── infrastructure/
│   ├── apps/
│   └── environments/
│       ├── dev/
│       ├── test/
│       └── prod/
├── security/
│   ├── policy/
│   ├── scanning/
│   ├── sbom-signing/
│   ├── secrets/
│   └── rbac/
├── observability/
│   ├── pipeline/
│   ├── deployments/
│   └── platform/
├── testing/
│   ├── contracts/
│   ├── integration/
│   └── e2e/
├── operations/
│   └── runbooks/
└── docs/
    ├── adr/
    ├── standards/
    └── onboarding/
```

## Control-plane rule

The directory structure is intentionally split by responsibility. Normal application-team infrastructure changes are request-driven: developers edit `iac-requests`, while Platform/SRE owns the Terraform modules, root stacks, schemas, defaults, policy, state and identities.

Normal CI is also profile-driven: application teams select an approved build profile in an application definition; Platform/SRE owns build images, dependency/cache policy, security controls, artifact metadata and reusable workflow implementation.

Normal CD is promotion-driven: a tested immutable artifact digest is promoted through DEV -> TEST -> PROD by a release request. The release catalog owns deployment strategy, verification and rollback behavior; Flux is the target AKS reconciliation control plane.

Production implementation starts only after the management framework, state boundaries, identity boundaries, validation and protected environment model are stable.
