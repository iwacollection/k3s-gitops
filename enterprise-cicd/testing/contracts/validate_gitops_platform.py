from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REPO_ROOT = ROOT.parent


def load(path: Path):
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def require_promotion_branch(workflow: str, environment: str, branch: str) -> None:
    pattern = rf"\b{re.escape(environment)}\)\s+BASE_BRANCH=\"{re.escape(branch)}\"\s*;;"
    require(re.search(pattern, workflow) is not None, f"{environment.upper()} promotion must target {branch}")


def main() -> None:
    policy = load(ROOT / "gitops" / "contracts" / "gitops-policy.json")["spec"]
    require(policy["deploymentMode"] == "pull", "GitOps must remain pull based")
    require(policy["directCiClusterWrite"] is False, "CI must not directly write Kubernetes")
    require(policy["artifactIdentity"] == "sha256-digest", "GitOps must promote immutable digests")
    require(policy["rebuildDuringPromotion"] is False, "promotion must not rebuild artifacts")
    require(policy["allowedTransitions"] == ["build->dev", "dev->test", "test->prod"], "unexpected promotion graph")

    dev_cluster = load(ROOT / "gitops" / "clusters" / "aks-automatic-lab" / "cluster.json")
    test_cluster = load(ROOT / "gitops" / "clusters" / "aks-automatic-lab-test" / "cluster.json")
    require(dev_cluster["metadata"]["environment"] == "dev", "DEV binding changed unexpectedly")
    require(test_cluster["metadata"]["environment"] == "test", "TEST binding must target test")
    require(dev_cluster["spec"]["namespaceManagement"] == "gitops", "DEV namespace must remain GitOps managed")
    require(test_cluster["spec"]["namespaceManagement"] == "arm", "TEST namespace must remain ARM managed")
    require(test_cluster["spec"]["labMode"] == "logical-environment-on-shared-aks", "TEST must remain logical/shared-AKS")
    require(test_cluster["spec"]["azure"]["resourceGroup"] == dev_cluster["spec"]["azure"]["resourceGroup"], "TEST lab must reuse DEV AKS resource group")
    require(test_cluster["spec"]["azure"]["clusterName"] == dev_cluster["spec"]["azure"]["clusterName"], "TEST lab must reuse DEV AKS cluster")

    dev_flux = dev_cluster["spec"]["flux"]
    test_flux = test_cluster["spec"]["flux"]
    require(dev_flux["branch"] == "gitops/dev", "DEV Flux must track gitops/dev")
    require(test_flux["configurationName"] == "enterprise-cicd-test", "TEST Flux name changed unexpectedly")
    require(test_flux["namespace"] == "enterprise-cicd-test", "TEST Flux namespace changed unexpectedly")
    require(test_flux["branch"] == "gitops/test", "TEST Flux must track gitops/test")
    test_kustomizations = {item["name"]: item for item in test_flux["kustomizations"]}
    require(set(test_kustomizations) == {"apps-test"}, "TEST Flux must reconcile only apps-test")
    require(test_kustomizations["apps-test"]["path"] == "./enterprise-cicd/gitops/environments/test", "TEST path changed unexpectedly")
    require(test_kustomizations["apps-test"]["prune"] is True, "TEST pruning must remain enabled")

    activation = load(ROOT / "activation" / "test" / "activation-contract.json")
    spec = activation["spec"]
    require(activation["metadata"]["environment"] == "test", "TEST activation contract must target test")
    require(spec["identity"]["strategy"] == "dedicated-user-assigned-managed-identity", "TEST must use a dedicated UAMI")
    require(spec["identity"]["subject"] == "repo:iwacollection/k3s-gitops:environment:test", "TEST OIDC subject must be environment:test")
    roles = {item["role"] for item in spec["identity"]["minimumRoles"]}
    require(roles == {"Reader", "Azure Kubernetes Service Cluster User Role", "Azure Kubernetes Service RBAC Reader", "AcrPull"}, "unexpected TEST role set")
    forbidden = set(spec["identity"]["forbiddenRoles"])
    require({"Owner", "Contributor", "User Access Administrator", "Azure Kubernetes Service RBAC Writer", "Azure Kubernetes Service RBAC Admin", "AcrPush"}.issubset(forbidden), "TEST forbidden-role guard incomplete")
    require(spec["artifact"]["rebuildAllowed"] is False, "TEST must not rebuild")
    require(spec["artifact"]["sameDigestRequired"] is True, "TEST must preserve digest")
    require(spec["controls"]["defaultMode"] == "plan-only", "TEST activation must default plan-only")
    require(spec["controls"]["applyRequiresExplicitFlag"] is True, "TEST activation must require --apply")
    require(spec["controls"]["fluxRemainsOnlyKubernetesWriter"] is True, "Flux must remain the only TEST Kubernetes writer")

    for env in ("dev", "test", "prod"):
        env_dir = ROOT / "gitops" / "environments" / env
        require((env_dir / "kustomization.yaml").is_file(), f"missing {env} Kustomize root")
        namespace = (env_dir / "namespace.yaml").read_text(encoding="utf-8")
        require(f"name: cicd-{env}" in namespace, f"unexpected namespace for {env}")

    promotion = (REPO_ROOT / ".github" / "workflows" / "gitops-promotion.yml").read_text(encoding="utf-8")
    for token in ("kubectl apply", "helm upgrade", "helm install", "az aks get-credentials"):
        require(token not in promotion, f"promotion contains direct deployment command: {token}")
    require("gh pr create" in promotion, "promotion must create a GitOps PR")
    require("kubectl kustomize" in promotion, "promotion must validate rendered desired state")
    require("sourceReleaseRequest" in promotion, "promotion must enforce immutable release lineage")
    require("NAMESPACE_MANAGEMENT" in promotion, "promotion must resolve namespace ownership")
    require("--namespace-management" in promotion, "renderer must receive namespace ownership explicitly")
    require("/tmp/platform-control/enterprise-cicd/promotion/render_gitops_overlay.py" in promotion, "promotion must freeze platform renderer before desired-state checkout")
    require("ARM-managed environment must not render a Namespace resource" in promotion, "ARM namespace ownership must be protected at render gate")
    require_promotion_branch(promotion, "dev", "gitops/dev")
    require_promotion_branch(promotion, "test", "gitops/test")
    require_promotion_branch(promotion, "prod", "gitops/prod")

    renderer = (ROOT / "promotion" / "render_gitops_overlay.py").read_text(encoding="utf-8")
    require('VALID_NAMESPACE_MANAGEMENT = {"gitops", "arm"}' in renderer, "renderer namespace ownership modes changed")
    require('if namespace_management == "gitops"' in renderer, "renderer must only include namespace.yaml for GitOps-owned namespaces")

    dev_bootstrap = (ROOT / "gitops" / "clusters" / "aks-automatic-lab" / "bootstrap-flux-aks.sh").read_text(encoding="utf-8")
    require("--apply" in dev_bootstrap and "PLAN ONLY" in dev_bootstrap, "DEV Flux bootstrap must be guarded")
    require('BRANCH="gitops/dev"' in dev_bootstrap, "DEV Flux bootstrap must target gitops/dev")

    identity_bootstrap = (ROOT / "activation" / "test" / "bootstrap-test-identity.sh").read_text(encoding="utf-8")
    require("PLAN ONLY" in identity_bootstrap, "TEST identity bootstrap must default plan-only")
    require('APPLY=0' in identity_bootstrap and 'APPLY=1' in identity_bootstrap, "TEST identity bootstrap must gate writes")
    require('SUBJECT="repo:iwacollection/k3s-gitops:environment:test"' in identity_bootstrap, "TEST OIDC subject changed")
    require("ensure_role_rest()" in identity_bootstrap, "TEST identity bootstrap must use REST-compatible role assignment")
    require('ensure_role_rest "Reader" "$READER_ROLE_ID" "$AKS_ID"' in identity_bootstrap, "TEST Reader must be AKS-scoped")
    require('ensure_role_rest "Azure Kubernetes Service Cluster User Role" "$AKS_CLUSTER_USER_ROLE_ID" "$AKS_ID"' in identity_bootstrap, "TEST Cluster User role must be AKS-scoped")
    require('ensure_role_rest "Azure Kubernetes Service RBAC Reader" "$AKS_RBAC_READER_ROLE_ID" "$TEST_NAMESPACE_SCOPE"' in identity_bootstrap, "TEST AKS RBAC Reader must be namespace scoped")
    require('ensure_role_rest "AcrPull" "$ACR_PULL_ROLE_ID" "$ACR_ID"' in identity_bootstrap, "TEST identity must be AcrPull-only")
    for forbidden_token in ('AcrPush" "$', 'Contributor" "$', 'Owner" "$'):
        require(forbidden_token not in identity_bootstrap, f"TEST runtime bootstrap contains forbidden role token: {forbidden_token}")

    flux_bootstrap = (ROOT / "gitops" / "clusters" / "aks-automatic-lab-test" / "bootstrap-flux-aks-test.sh").read_text(encoding="utf-8")
    require("PLAN ONLY" in flux_bootstrap, "TEST Flux bootstrap must default plan-only")
    require('APPLY=0' in flux_bootstrap and 'APPLY=1' in flux_bootstrap, "TEST Flux bootstrap must gate writes")
    require('CONFIG_NAME="enterprise-cicd-test"' in flux_bootstrap, "TEST Flux config name changed")
    require('BRANCH="gitops/test"' in flux_bootstrap, "TEST Flux bootstrap must target gitops/test")
    require('KUSTOMIZATION_NAME="apps-test"' in flux_bootstrap, "TEST Flux must reconcile apps-test")
    require("az rest --method put" in flux_bootstrap, "TEST Flux bootstrap must support old CLI through ARM REST")
    require("gitops/infrastructure" not in flux_bootstrap, "TEST logical Flux must not duplicate shared infrastructure")

    print("GitOps platform contracts validated.")


if __name__ == "__main__":
    main()
