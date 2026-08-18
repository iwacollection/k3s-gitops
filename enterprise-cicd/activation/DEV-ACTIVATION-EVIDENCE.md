# Azure DEV Activation Evidence

## Status

The enterprise CI/CD control plane has completed a real DEV end-to-end activation against the existing Azure AKS lab environment.

This is not a Terraform dry run or a mocked deployment path.

## Azure target

- Subscription: `c12c3a36-99d8-4741-bcef-cd7df5d5cd4a`
- Resource group: `group-test`
- AKS: `k8s-test-cicd`
- Kubernetes namespace: `cicd-dev`
- ACR: `acrcicdc12c3a3699d8.azurecr.io`
- Flux configuration: `enterprise-cicd`
- Flux configuration namespace: `enterprise-cicd`
- Flux desired-state branch: `gitops/dev`

## Identity path

GitHub Actions authenticates to Azure through GitHub OIDC and the existing user-assigned managed identity.

- No Azure client secret is required for DEV.
- Federated credential subject: `repo:iwacollection/k3s-gitops:environment:dev`
- Azure permissions remain scoped to the required DEV resources.
- Kubernetes deployment writes are owned by Flux, not by the CI workflow.

## Platform build images

The following versioned build images were published to ACR and verified by immutable digest:

| Build image | Digest |
|---|---|
| `build/java21-maven:v1` | `sha256:02ea4848f16f7d70811bcd1c66b78354648510341d835ab06154eb3052dcbaf6` |
| `build/python-uv:v1` | `sha256:f6d63e38fbb3bd2e1edae918afbc1e3abafdb0f4dc961449d33f5c2d8722c02d` |
| `build/go-builder:v1` | `sha256:813d1bcbe71bb2bdaebcb622c4af65d5a02ee6196e98c0aed3535109f51f5ace` |
| `build/cpp-cmake-conan:v1` | `sha256:8864bafcd66839cc76577f450c4988b0d06d4e3be6bcf3ba6b29c332faf6fb6e` |

## Real application CI

E2E application: `platform-smoke-api`

The governed CI v2 path completed:

`Application Definition -> immutable platform build image -> dependency cache isolation -> compile -> test -> source scan -> application image build -> container scan -> SBOM -> BuildKit provenance -> Cosign OIDC signing -> Release Evidence`

Final releasable application artifact:

- Repository: `acrcicdc12c3a3699d8.azurecr.io/apps/platform-smoke-api`
- Digest: `sha256:b0faf7a8f90618cd7a6b081085d3af3ca666afa015aac9827f71cf198816e2ba`
- Signed: yes
- SBOM: yes
- Provenance: yes
- Source scan: passed
- Container vulnerability scan: passed

## Governed DEV promotion

The real Release Request is:

`enterprise-cicd/release-requests/platform-smoke-api-to-dev.json`

Promotion produced a dedicated Desired-State branch from the `gitops/dev` baseline. The resulting PR changed only:

- `enterprise-cicd/gitops/environments/dev/apps/platform-smoke-api/kustomization.yaml`
- `enterprise-cicd/gitops/environments/dev/apps/platform-smoke-api/release-evidence.json`
- `enterprise-cicd/gitops/environments/dev/kustomization.yaml`

Promotion PR #6 passed GitOps/CD/framework checks and was merged into `gitops/dev` as commit:

`37ae91eed8e2c40038524d1b524111056dc637ce`

## Flux / AKS verification

Read-only DEV verification passed after Flux reconciliation.

Observed state:

- Flux compliant: `true`
- Deployment: `platform-smoke-api`
- Namespace: `cicd-dev`
- Desired replicas: `1`
- Available replicas: `1`
- Ready replicas: `1`
- Deployed image exactly equals the approved ACR digest
- EndpointSlices: `1`
- Ready endpoints: `1`
- Verification result: `passed`

Exact deployed image:

`acrcicdc12c3a3699d8.azurecr.io/apps/platform-smoke-api@sha256:b0faf7a8f90618cd7a6b081085d3af3ca666afa015aac9827f71cf198816e2ba`

The verification evidence is retained as the GitHub Actions artifact from `Platform Smoke DEV Observe` run `32178372834`.

## Proven real DEV chain

`GitHub OIDC -> Azure -> ACR -> immutable build image -> Application CI -> immutable application digest -> Release Request -> protected GitOps PR -> gitops/dev -> Flux -> AKS -> Deployment Ready -> Endpoint Ready -> exact digest verification`

## Boundaries still intentionally enforced

- PR #5 remains Draft and is not merged to `main`.
- Production Terraform Apply is not enabled by this DEV activation.
- PostgreSQL PROD remains blocked until a real Entra DBA group object ID and principal name are supplied.
- TEST and PROD promotion remain separate governed environments.
