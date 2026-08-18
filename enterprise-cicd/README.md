# Azure Enterprise CI/CD Platform

This directory bootstraps an enterprise CI/CD platform for Microsoft Azure with two pipeline entry points:

- Azure DevOps Pipelines
- GitHub Actions

The execution model is shared: versioned build environments, common CI scripts, immutable artifacts, Terraform-managed infrastructure, Helm-based deployment, short-lived cloud credentials, and protected production promotion.

## Target architecture

```text
GitHub / Azure Repos
        |
        +-------------------------+
        |                         |
GitHub Actions              Azure Pipelines
        |                         |
Reusable Workflow           Required Template
        |                         |
        +-----------+-------------+
                    |
             Pipeline Contract
                    |
        +-----------+------------+
        |           |            |
      Build       Infra        Deploy
        |           |            |
   Build Images  Terraform     Helm
        |           |            |
        +-----------+------------+
                    |
                  Azure
        +-----------+------------+
        |           |            |
       ACR      State Storage   Existing AKS Automatic
```

## Current real Azure target

- Resource group: `group-test`
- AKS: `k8s-test-cicd`
- AKS SKU: Automatic / Standard
- Deployment environment: `dev`
- Deployment namespace: `cicd-dev`
- Container registry: created by the GitHub/Azure bootstrap script as Standard ACR
- Authentication: GitHub Actions OIDC -> Microsoft Entra user-assigned managed identity

The platform reuses the existing AKS Automatic cluster. It does not create a second AKS cluster.

## Core rules

1. Build environment is versioned and reproducible; do not rely on a mutable long-lived build host.
2. Build once, promote the same artifact digest through dev/staging/prod.
3. Terraform plan and apply are separate trust boundaries.
4. Production deployment must use protected environments and approval checks.
5. Prefer OIDC / Workload Identity Federation instead of long-lived client secrets.
6. Shared dependency services may cache packages, but writable job workspaces stay isolated.
7. GitHub Actions and Azure Pipelines are adapters; common build/deploy behavior belongs in shared scripts/templates.
8. The CentOS 7 administration host is bootstrap-only and is not a CI runner standard.

## First runnable deployment path

```text
GitHub Actions (dev environment)
        |
        | OIDC
        v
Microsoft Entra ID
        |
        v
User-assigned managed identity
        |
        +---- AcrPush ----> Azure Container Registry
        |
        +---- AKS RBAC ---> k8s-test-cicd
                              |
                              v
                         Helm release
                              |
                              v
                           cicd-dev
```

The first smoke workload is `enterprise-cicd/examples/go-smoke`. Images are tagged with the Git commit SHA and deployed through `enterprise-cicd/helm/go-smoke`.

## Phase 1 contents

```text
enterprise-cicd/
├── README.md
├── contracts/
│   └── pipeline-contract.yaml
├── examples/
│   └── go-smoke/
├── helm/
│   └── go-smoke/
├── scripts/
│   └── bootstrap-github-azure-dev.sh
├── terraform/
│   └── bootstrap/
└── azure-pipelines/
    └── templates/

.github/workflows/
├── enterprise-ci-reusable.yml
└── azure-dev-smoke-deploy.yml
```

## Next platform layers

- Managed DevOps Pools with curated Azure Compute Gallery images
- GitHub Actions ephemeral runner strategy (GitHub-hosted first, ARC on AKS only when private-network/self-hosting is required)
- Language build images for Go / Python / Java / C++
- Azure Artifacts or Nexus/Artifactory dependency proxy
- Staging and production Helm environments
- SBOM, signing, SAST/SCA, policy gates
- Azure DevOps approvals/checks and GitHub protected environments
- Observability for queue time, build time, failure rate, cache hit rate, deployment frequency and rollback rate
