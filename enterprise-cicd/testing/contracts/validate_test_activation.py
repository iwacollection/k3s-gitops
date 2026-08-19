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

    identity = spec["identity"]
    require(identity["strategy"] == "dedicated-user-assigned-managed-identity", "TEST must use a dedicated UAMI")
    require(identity["name"] == "k3s-gitops-test-uami", "unexpected TEST UAMI name")
    require(identity["subject"] == "repo:iwacollection/k3s-gitops:environment:test", "TEST OIDC subject must be environment:test")

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
    require('ensure_role "Reader" "$AKS_ID"' in identity_bootstrap, "TEST Reader must be scoped to AKS")
    require('ensure_role "Reader" "$RG_ID"' not in identity_bootstrap, "resource-group Reader is forbidden for TEST runtime identity")
    require('ensure_role "Azure Kubernetes Service Cluster User Role" "$AKS_ID"' in identity_bootstrap, "TEST must have non-admin kubeconfig access")
    require('ensure_role "Azure Kubernetes Service RBAC Reader" "$TEST_NAMESPACE_SCOPE"' in identity_bootstrap, "TEST Kubernetes read role must be namespace scoped")
    require('ensure_role "AcrPull" "$ACR_ID"' in identity_bootstrap, "TEST artifact access must be pull-only")
    for role in ("AcrPush", "Contributor", "Owner", "Azure Kubernetes Service RBAC Writer", "Azure Kubernetes Service RBAC Admin"):
        require(f'ensure_role "{role}"' not in identity_bootstrap, f"TEST identity bootstrap must not assign {role}")
    require('test-identity-activation-result.json' in identity_bootstrap, "TEST identity bootstrap must emit structured activation evidence")

    flux_bootstrap = (ROOT / "gitops" / "clusters" / "aks-automatic-lab-test" / "bootstrap-flux-aks-test.sh").read_text(encoding="utf-8")
    require('CONFIG_NAME="enterprise-cicd-test"' in flux_bootstrap, "unexpected TEST Flux configuration name")
    require('CONFIG_NAMESPACE="enterprise-cicd-test"' in flux_bootstrap, "unexpected TEST Flux namespace")
    require('BRANCH="gitops/test"' in flux_bootstrap, "TEST Flux must reconcile gitops/test")
    require('KUSTOMIZATION_NAME="apps-test"' in flux_bootstrap, "TEST Flux must reconcile apps-test")
    require('KUSTOMIZATION_PATH="./enterprise-cicd/gitops/environments/test"' in flux_bootstrap, "TEST Flux path changed unexpectedly")
    require('APPLY=0' in flux_bootstrap and 'APPLY=1' in flux_bootstrap and '--apply' in flux_bootstrap, "TEST Flux writes must require explicit --apply")
    require('gitops/infrastructure' not in flux_bootstrap, "TEST logical Flux config must not duplicate shared infrastructure ownership")

    readiness = (REPO_ROOT / ".github" / "workflows" / "azure-test-readiness-inventory.yml").read_text(encoding="utf-8")
    require('environment: dev' in readiness, "TEST readiness must preserve the DEV inventory identity path")
    require('environment: test' in readiness, "TEST readiness must perform a real TEST OIDC probe")
    require("test-identity-probe:" in readiness, "TEST readiness is missing TEST identity probe job")
    require("test-oidc-or-rbac-probe-failed" in readiness, "TEST readiness must block on failed real OIDC/RBAC probe")
    require("testOidcAndNamespaceRbacProbe" in readiness, "TEST readiness evidence must record TEST identity probe status")
    require('test "$PRINCIPAL_ID" != "$DEV_PRINCIPAL"' in readiness, "TEST readiness must reject reused DEV principal")
    require('test "$(kubectl auth can-i create deployments.apps --namespace cicd-test)" = no' in readiness, "TEST readiness must prove no Deployment create")
    require('test "$(kubectl auth can-i patch deployments.apps --namespace cicd-test)" = no' in readiness, "TEST readiness must prove no Deployment patch")
    require('test "$(kubectl auth can-i delete deployments.apps --namespace cicd-test)" = no' in readiness, "TEST readiness must prove no Deployment delete")

    observer = (REPO_ROOT / ".github" / "workflows" / "platform-smoke-test-observe.yml").read_text(encoding="utf-8")
    require('environment: test' in observer, "TEST observer must use GitHub environment:test")
    require('.environments.test.identities.githubOidc.clientId' in observer, "TEST observer must resolve TEST OIDC binding")
    require('test "$PRINCIPAL_ID" != "$DEV_PRINCIPAL"' in observer, "TEST observer must reject the DEV principal")
    require('test "$(kubectl auth can-i create deployments.apps --namespace cicd-test)" = no' in observer, "TEST observer must prove no Deployment create")
    require('test "$(kubectl auth can-i patch deployments.apps --namespace cicd-test)" = no' in observer, "TEST observer must prove no Deployment patch")
    require('test "$(kubectl auth can-i delete deployments.apps --namespace cicd-test)" = no' in observer, "TEST observer must prove no Deployment delete")
    require('test "$DIGEST" = "$(jq -r .spec.artifactDigest "$DEV_REQUEST")"' in observer, "TEST observer must prove same DEV digest")
    for command in ("kubectl apply", "kubectl create", "kubectl patch", "kubectl delete", "helm upgrade", "helm install"):
        require(command not in observer, f"TEST observer contains forbidden mutation command: {command}")

    print("TEST activation contracts validated.")


if __name__ == "__main__":
    main()
