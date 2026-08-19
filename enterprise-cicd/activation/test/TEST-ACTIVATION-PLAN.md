# Azure TEST Activation Plan

## Current evidence

Real TEST readiness inventory has completed against the Azure lab.

- Readiness workflow: `Azure TEST Readiness Inventory`
- Evidence run: `32208945916`
- Physical AKS: existing `group-test / k8s-test-cicd`
- ACR artifact: available
- DEV inventory identity cluster-scope namespace visibility: denied as expected
- TEST desired-state branch: `gitops/test` exists
- TEST namespace manifest: `cicd-test` exists in Git
- TEST physical AKS/VNet creation: not required by Lab contract

Current blockers are exactly:

```text
missing-test-github-oidc-binding
missing-test-flux-configuration
```

## Artifact invariant

TEST must promote the exact DEV-approved artifact. No rebuild is allowed.

```text
acrcicdc12c3a3699d8.azurecr.io/apps/platform-smoke-api
@sha256:b0faf7a8f90618cd7a6b081085d3af3ca666afa015aac9827f71cf198816e2ba
```

## Target TEST logical boundaries

```text
Physical AKS:          k8s-test-cicd        (shared Lab boundary)
GitHub Environment:   test
GitOps branch:         gitops/test
Kubernetes namespace: cicd-test
Flux configuration:   enterprise-cicd-test
Flux namespace:       enterprise-cicd-test
Runtime identity:     k3s-gitops-test-uami
OIDC subject:         repo:iwacollection/k3s-gitops:environment:test
```

The shared Lab cluster does not mean shared deployment identity. DEV and TEST must remain separate principals and separate namespace RBAC boundaries.

## Phase A — activate dedicated TEST OIDC identity

Privileged platform bootstrap operator runs:

```bash
bash enterprise-cicd/activation/test/bootstrap-test-identity.sh --apply
```

The script creates/reuses only:

1. `k3s-gitops-test-uami` in `sub-test`.
2. GitHub federated credential for `environment:test`.
3. `Reader` on resource group `group-test`.
4. `Azure Kubernetes Service Cluster User Role` on AKS `k8s-test-cicd`.
5. `Azure Kubernetes Service RBAC Reader` scoped only to `cicd-test`.
6. `AcrPull` on `acrcicdc12c3a3699d8`.

It must not grant `Owner`, `Contributor`, `User Access Administrator`, AKS RBAC Writer/Admin or `AcrPush` to the TEST runtime identity.

The command returns the real:

```text
clientId
principalId
tenantId
subscriptionId
resourceId
```

These IDs must then be committed into:

```text
enterprise-cicd/contracts/environment-bindings.json
.environments.test.identities.githubOidc
```

Do not invent IDs and do not copy DEV's principal into TEST.

## Gate A — rerun TEST readiness

After the Binding is committed, rerun `Azure TEST Readiness Inventory`.

Expected state after Phase A:

```text
testGithubOidcBinding = true
artifactAvailable      = true
devIdentityClusterScopeVisible = false
blocker remaining      = missing-test-flux-configuration
```

If any other blocker appears, stop activation and investigate before writing Flux state.

## Phase B — activate TEST Flux configuration

Privileged platform bootstrap operator runs:

```bash
bash enterprise-cicd/gitops/clusters/aks-automatic-lab-test/bootstrap-flux-aks-test.sh --apply
```

The TEST Flux configuration must be exactly:

```text
configuration: enterprise-cicd-test
namespace:     enterprise-cicd-test
branch:        gitops/test
kustomization: apps-test
path:          ./enterprise-cicd/gitops/environments/test
prune:         true
```

The TEST configuration deliberately does not reconcile `gitops/infrastructure`; shared Lab infrastructure is already owned by the DEV Lab Flux configuration. This avoids two Flux configurations owning the same Kubernetes resources.

## Gate B — readiness must become ready

Rerun `Azure TEST Readiness Inventory`.

Expected result:

```text
status = ready
blockers = []
testGithubOidcBinding = true
testFluxConfiguration = true
testFluxBranchMatch = true
artifactAvailable = true
```

Only after this gate is green may the real DEV -> TEST release request be committed.

## Phase C — promote the same digest

Create a real Release Request:

```text
from: dev
to: test
artifactRepository: acrcicdc12c3a3699d8.azurecr.io/apps/platform-smoke-api
artifactDigest: sha256:b0faf7a8f90618cd7a6b081085d3af3ca666afa015aac9827f71cf198816e2ba
releaseProfile: rolling/rolling-v1
```

The generic GitOps Promotion workflow must then:

```text
Release Request
 -> base from gitops/test
 -> render cicd-test overlay
 -> immutable digest check
 -> protected GitOps PR
 -> merge to gitops/test
 -> Flux enterprise-cicd-test reconciliation
```

No CI rebuild occurs in this phase.

## Phase D — TEST verification

The TEST observation workflow must authenticate only through `environment:test` and verify:

1. Flux `enterprise-cicd-test` is compliant.
2. Flux source commit contains the merged `gitops/test` commit.
3. Deployment is in `cicd-test`.
4. Deployed image exactly equals the DEV-approved digest.
5. Available replicas equal desired replicas.
6. At least one ready EndpointSlice endpoint exists.
7. TEST identity cannot mutate Kubernetes resources.

Successful verification becomes the evidence required for the later TEST -> PROD promotion.

## Safety boundary

Until Phase A and Phase B are explicitly run with `--apply`, this TEST activation package performs no Azure mutation.
