# Azure Enterprise CI/CD Platform

This directory bootstraps an enterprise CI/CD platform for Microsoft Azure with two pipeline entry points:

- Azure DevOps Pipelines
- GitHub Actions

The execution model is shared: versioned build environments, common CI scripts, immutable artifacts, Terraform-managed infrastructure, Helm-based deployment, short-lived cloud credentials, and protected production promotion.

## Current lab target

The existing Azure deployment target is reused instead of creating a second Kubernetes cluster:

- AKS cluster: `k8s-test-cicd`
- Resource group: `group-test`
- Region: `eastus`
- SKU: AKS Automatic
- Tier: Standard
- Node provisioning: Automatic / NAP
- Kubernetes API access: isolated kubeconfig + `kubelogin`

The CI/CD bootstrap Terraform therefore does **not** create AKS. AKS remains an external deployment target for the application delivery layer.

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
        +-----------+-------------------+
        |           |                   |
 ACR Standard   State Storage     Existing AKS Automatic
```

## Core rules

1. Build environment is versioned and reproducible; do not rely on a mutable long-lived build host.
2. Build once, promote the same artifact digest through dev/staging/prod.
3. Terraform plan and apply are separate trust boundaries.
4. Production deployment must use protected environments and approval checks.
5. Prefer OIDC / Workload Identity Federation instead of long-lived client secrets.
6. Shared dependency services may cache packages, but writable job workspaces stay isolated.
7. GitHub Actions and Azure Pipelines are adapters; common build/deploy behavior belongs in shared scripts/templates.
8. Lab automation is cost-aware: read-only inventory and plan come before creating billable Azure resources.

## Phase 1 contents

```text
enterprise-cicd/
├── README.md
├── contracts/
│   └── pipeline-contract.yaml
├── scripts/
│   ├── azure-preflight.sh
│   ├── terraform-bootstrap-plan.sh
│   ├── aks-automatic-cost-inventory.sh
│   ├── install-kubelogin-centos7.sh
│   └── azure-cost-month-to-date.sh
├── terraform/
│   └── bootstrap/
│       ├── versions.tf
│       ├── variables.tf
│       ├── main.tf
│       ├── outputs.tf
│       └── terraform.tfvars.example
└── azure-pipelines/
    └── templates/
        └── enterprise-ci.yml

.github/workflows/
└── enterprise-ci-reusable.yml
```

## Next platform layers

- Azure workload identities / OIDC federation for GitHub Actions and Azure DevOps
- ACR Standard for versioned build and application images
- Managed DevOps Pools with curated Azure Compute Gallery images
- GitHub Actions ephemeral runner strategy when private-network/self-hosting is required
- Language build images for Go / Python / Java / C++
- Azure Artifacts or Nexus/Artifactory dependency proxy
- Helm delivery into the existing AKS Automatic cluster
- SBOM, signing, SAST/SCA, policy gates
- Azure DevOps approvals/checks and GitHub protected environments
- Observability for queue time, build time, failure rate, cache hit rate, deployment frequency and rollback rate
