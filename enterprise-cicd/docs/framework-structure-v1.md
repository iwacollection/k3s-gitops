# Enterprise IaC + CI/CD Framework Structure V1

```text
enterprise-cicd/
├── architecture/                 # control-plane architecture and ownership boundaries
├── contracts/                    # machine-readable environment/state/identity/repository contracts
├── terraform/
│   ├── bootstrap/                # creates only IaC prerequisites
│   ├── state/                    # backend/state-key rendering
│   ├── modules/                  # reusable Terraform modules
│   │   ├── resource-group/
│   │   ├── managed-identity/
│   │   ├── acr/
│   │   ├── network/
│   │   ├── aks/
│   │   └── workload-base/
│   └── stacks/                   # root modules / state boundaries
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

The directory structure is intentionally split by responsibility. Application CI, Azure infrastructure delivery and Kubernetes GitOps CD are separate control paths. Production implementation starts only after the management framework, state boundaries, identity boundaries, validation and protected environment model are stable.
