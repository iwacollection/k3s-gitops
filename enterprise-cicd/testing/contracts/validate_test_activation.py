from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REPO_ROOT = ROOT.parent


def load(path: Path):
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def main() -> None:
    activation = load(ROOT / "activation" / "test" / "activation-contract.json")
    spec = activation["spec"]
    require(activation["metadata"] == {"environment": "test", "mode": "logical-environment-on-shared-aks"}, "unexpected TEST activation metadata")
    require(spec["physicalBoundary"]["sharedWithDevInLab"] is True, "TEST Lab activation must share only the physical AKS boundary")
    require(spec["logicalBoundaries"] == {
        "githubEnvironment": "test",
        "gitopsBranch": "gitops/test",
        "kubernetesNamespace": "cicd-test",
        "fluxConfiguration": "enterprise-cicd-test",
        "fluxNamespace": "enterprise-cicd-test",
    }, "unexpected TEST logical boundaries")

    github_environment = load(ROOT / "activation" / "test" / "github-environment-policy.json")
    github_spec = github_environment["spec"]
    require(github_environment["metadata"]["name"] == "test", "GitHub TEST environment policy must target test")
    require(github_spec["mustExistBeforeAzureFederation"] is True, "TEST GitHub Environment must pre-exist Azure federation")
    require(github_spec["implicitCreationAllowed"] is False, "implicit TEST GitHub Environment creation is forbidden")
    require(github_spec["oidcSubject"] == "repo:iwacollection/k3s-gitops:environment:test", "GitHub TEST environment OIDC subject changed unexpectedly")
    require(github_spec["deploymentBranchPolicy"]["mode"] == "selected-branches", "TEST GitHub Environment must restrict deployment branches")
    allowed_branches = set(github_spec["deploymentBranchPolicy"]["allowed"])
    require("design/azure-enterprise-control-plane-v1" in allowed_branches, "current activation branch must be explicitly allowed in TEST Environment")
    require("main" in allowed_branches, "main must be predeclared as a trusted TEST Environment branch")
    require(github_spec["environmentSecretsRequired"] is False, "TEST OIDC must not require long-lived environment secrets")
    require(github_spec["longLivedAzureCredentialsAllowed"] is False, "long-lived Azure credentials are forbidden in TEST Environment")
    require(github_spec["requiredWorkflowProperties"]["idTokenWrite"] is True, "TEST workflows must use OIDC id-token write")
    require(github_spec["requiredWorkflowProperties"]["azureClientSecretForbidden"] is True, "Azure client secrets are forbidden in TEST workflows")

    identity = spec["identity"]
    require(identity["strategy"] == "dedicated-user-assigned-managed-identity", "TEST must use a dedicated UAMI")
    require(identity["name"] == "k3s-gitops-test-uami", "unexpected TEST UAMI name")
    require(identity["subject"] == github_spec["oidcSubject"], "Azure TEST federation subject must equal the GitHub Environment trust subject")

    role_scopes = {(item["role"], item["scope"]) for item in identity["minimumRoles"]}
    expected_role_scopes = {
        ("Reader", "aks:k8s-test-cicd"),
        ("Azure Kubernetes Service Cluster User Role", "aks:k8s-test-cicd"),
        ("Azure Kubernetes Service RBAC Reader", "aks:k8s-test-cicd/namespace:cicd-test"),
        ("AcrPull", "acr:acrcicdc12c3a3699d8"),
    }
    require(role_scopes == expected_role_scopes, "TEST runtime identity role scopes are not least privilege")
    require(all(not scope.startswith("resource-group:") for _, scope in role_scopes), "TEST runtime identity must not have resource-group-wide role scope")

    forbidden = set(identity["forbiddenRoles"])
    require({
        "Owner",
        "Contributor",
        "User Access Administrator",
        "Azure Kubernetes Service RBAC Writer",
        "Azure Kubernetes Service RBAC Admin",
        "AcrPush",
    }.issubset(forbidden), "TEST forbidden-role guard is incomplete")

    dev_release = load(ROOT / "release-requests" / "platform-smoke-api-to-dev.json")
    artifact = spec["artifact"]
    require(artifact["sourceEnvironment"] == "dev" and artifact["targetEnvironment"] == "test", "TEST activation must be DEV -> TEST")
    require(artifact["digest"] == dev_release["spec"]["artifactDigest"], "TEST activation digest must equal the DEV-approved digest")
    require(artifact["repository"] == dev_release["spec"]["artifactRepository"], "TEST activation repository must equal the DEV-approved repository")
    require(artifact["rebuildAllowed"] is False, "TEST activation must not rebuild")
    require(artifact["sameDigestRequired"] is True, "TEST activation must require the same digest")

    controls = spec["controls"]
    require(controls == {
        "defaultMode": "plan-only",
        "applyRequiresExplicitFlag": True,
        "noNewAks": True,
        "noNewVnet": True,
        "noArtifactRebuild": True,
        "fluxRemainsOnlyKubernetesWriter": True,
    }, "TEST activation safety controls changed unexpectedly")

    identity_bootstrap = (ROOT / "activation" / "test" / "bootstrap-test-identity.sh").read_text(encoding="utf-8")
    require('APPLY=0' in identity_bootstrap and 'APPLY=1' in identity_bootstrap and '--apply' in identity_bootstrap, "TEST identity writes must require explicit --apply")
    require('ensure_role_rest "Reader" "$READER_ROLE_ID" "$AKS_ID"' in identity_bootstrap, "TEST Reader must be scoped to AKS")
    require('ensure_role_rest "Reader" "$READER_ROLE_ID" "$RG_ID"' not in identity_bootstrap, "resource-group Reader is forbidden for TEST runtime identity")
    require('ensure_role_rest "Azure Kubernetes Service Cluster User Role" "$AKS_CLUSTER_USER_ROLE_ID" "$AKS_ID"' in identity_bootstrap, "TEST must have non-admin kubeconfig access")
    require('ensure_role_rest "Azure Kubernetes Service RBAC Reader" "$AKS_RBAC_READER_ROLE_ID" "$TEST_NAMESPACE_SCOPE"' in identity_bootstrap, "TEST Kubernetes read role must be namespace scoped")
    require('ensure_role_rest "AcrPull" "$ACR_PULL_ROLE_ID" "$ACR_ID"' in identity_bootstrap, "TEST artifact access must be pull-only")
    for role in ("AcrPush", "Contributor", "Owner", "Azure Kubernetes Service RBAC Writer", "Azure Kubernetes Service RBAC Admin"):
        require(f'ensure_role_rest "{role}"' not in identity_bootstrap, f"TEST identity bootstrap must not assign {role}")
    require('test-identity-activation-result.json' in identity_bootstrap, "TEST identity bootstrap must emit structured activation evidence")
    require('az rest --method put --url "$FIC_URL"' in identity_bootstrap, "TEST OIDC federation must support old CLI through ARM REST")

    flux_bootstrap = (ROOT / "gitops" / "clusters" / "aks-automatic-lab-test" / "bootstrap-flux-aks-test.sh").read_text(encoding="utf-8")
    require('CONFIG_NAME="enterprise-cicd-test"' in flux_bootstrap, "unexpected TEST Flux configuration name")
    require('CONFIG_NAMESPACE="enterprise-cicd-test"' in flux_bootstrap, "unexpected TEST Flux namespace")
    require('BRANCH="gitops/test"' in flux_bootstrap, "TEST Flux must reconcile gitops/test")
    require('KUSTOMIZATION_NAME="apps-test"' in flux_bootstrap, "TEST Flux must reconcile apps-test")
    require('KUSTOMIZATION_PATH="./enterprise-cicd/gitops/environments/test"' in flux_bootstrap, "TEST Flux path changed unexpectedly")
    require('APPLY=0' in flux_bootstrap and 'APPLY=1' in flux_bootstrap and '--apply' in flux_bootstrap, "TEST Flux writes must require explicit --apply")
    require('az rest --method put --url "$FLUX_URL"' in flux_bootstrap, "TEST Flux activation must support old CLI through ARM REST")
    body_lines = [line for line in flux_bootstrap.splitlines() if line.strip().startswith("BODY=")]
    require(body_lines, "TEST Flux request body is missing")
    require("gitops/infrastructure" not in "\n".join(body_lines), "TEST logical Flux request must not duplicate shared infrastructure ownership")

    cluster_binding = load(ROOT / "gitops" / "clusters" / "aks-automatic-lab-test" / "cluster.json")
    require(cluster_binding["spec"]["namespaceManagement"] == "arm", "TEST ARM-owned namespace boundary changed unexpectedly")

    readiness = (REPO_ROOT / ".github" / "workflows" / "azure-test-readiness-inventory.yml").read_text(encoding="utf-8")
    require('environment: dev' in readiness, "TEST readiness must preserve the DEV inventory identity path")
    require('environment: test' in readiness, "TEST readiness must perform a real TEST OIDC probe")
    require("test-identity-probe:" in readiness, "TEST readiness is missing TEST identity probe job")
    require("test-oidc-or-rbac-probe-failed" in readiness, "TEST readiness must block on failed real OIDC/RBAC probe")
    require("testOidcAndNamespaceRbacProbe" in readiness, "TEST readiness evidence must record TEST identity probe status")
    require('test "$PRINCIPAL_ID" != "$DEV_PRINCIPAL_ID"' in readiness, "TEST readiness must reject reused DEV principal")
    require("CREATE_DEPLOY=\"$(kubectl auth can-i create deployments.apps --namespace cicd-test 2>&1 || true)\"" in readiness, "TEST readiness must capture Deployment create permission")
    require("PATCH_DEPLOY=\"$(kubectl auth can-i patch deployments.apps --namespace cicd-test 2>&1 || true)\"" in readiness, "TEST readiness must capture Deployment patch permission")
    require("DELETE_DEPLOY=\"$(kubectl auth can-i delete deployments.apps --namespace cicd-test 2>&1 || true)\"" in readiness, "TEST readiness must capture Deployment delete permission")
    require("grep -Eq '^no([[:space:]-]|$)' <<<\"$CREATE_DEPLOY\"" in readiness, "TEST readiness must require an explicit create denial")
    require("grep -Eq '^no([[:space:]-]|$)' <<<\"$PATCH_DEPLOY\"" in readiness, "TEST readiness must require an explicit patch denial")
    require("grep -Eq '^no([[:space:]-]|$)' <<<\"$DELETE_DEPLOY\"" in readiness, "TEST readiness must require an explicit delete denial")

    observer = (REPO_ROOT / ".github" / "workflows" / "platform-smoke-test-observe.yml").read_text(encoding="utf-8")
    require('environment: test' in observer, "TEST observer must use GitHub environment:test")
    require('.environments.test.identities.githubOidc.clientId' in observer, "TEST observer must resolve TEST OIDC binding")
    require('test "$PRINCIPAL_ID" != "$DEV_PRINCIPAL"' in observer, "TEST observer must reject the DEV principal")
    require("CREATE_DEPLOY=\"$(kubectl auth can-i create deployments.apps --namespace cicd-test 2>&1 || true)\"" in observer, "TEST observer must capture Deployment create permission")
    require("PATCH_DEPLOY=\"$(kubectl auth can-i patch deployments.apps --namespace cicd-test 2>&1 || true)\"" in observer, "TEST observer must capture Deployment patch permission")
    require("DELETE_DEPLOY=\"$(kubectl auth can-i delete deployments.apps --namespace cicd-test 2>&1 || true)\"" in observer, "TEST observer must capture Deployment delete permission")
    require("grep -Eq '^no([[:space:]-]|$)' <<<\"$CREATE_DEPLOY\"" in observer, "TEST observer must require an explicit create denial")
    require("grep -Eq '^no([[:space:]-]|$)' <<<\"$PATCH_DEPLOY\"" in observer, "TEST observer must require an explicit patch denial")
    require("grep -Eq '^no([[:space:]-]|$)' <<<\"$DELETE_DEPLOY\"" in observer, "TEST observer must require an explicit delete denial")
    require('test "$DIGEST" = "$(jq -r .spec.artifactDigest "$DEV_REQUEST")"' in observer, "TEST observer must prove same DEV digest")
    require("sameDigestFromDev:true" in observer, "TEST verification evidence must record same-digest promotion")
    require("mutationAccess:false" in observer, "TEST verification evidence must record read-only observer access")
    for command in ("kubectl apply", "kubectl create", "kubectl patch", "kubectl delete", "helm upgrade", "helm install"):
        require(command not in observer, f"TEST observer contains forbidden mutation command: {command}")

    print("TEST activation contracts validated.")


if __name__ == "__main__":
    main()
