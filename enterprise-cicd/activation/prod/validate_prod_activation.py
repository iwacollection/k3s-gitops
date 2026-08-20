#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
ROOT = REPO / "enterprise-cicd"
PROD = ROOT / "activation" / "prod"


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def main() -> None:
    activation_path = PROD / "activation-contract.json"
    env_policy_path = PROD / "github-environment-policy.json"
    identity_script_path = PROD / "bootstrap-prod-identity.sh"
    flux_script_path = ROOT / "gitops" / "clusters" / "aks-automatic-lab-prod" / "bootstrap-flux-aks-prod.sh"
    cluster_path = ROOT / "gitops" / "clusters" / "aks-automatic-lab-prod" / "cluster.json"
    observe_workflow_path = REPO / ".github" / "workflows" / "platform-smoke-prod-observe.yml"
    prod_root_path = ROOT / "gitops" / "environments" / "prod" / "kustomization.yaml"
    example_release_path = ROOT / "release-requests" / "platform-smoke-api-to-prod.example.json"
    test_release_path = ROOT / "release-requests" / "platform-smoke-api-to-test.json"
    bindings_path = ROOT / "contracts" / "environment-bindings.json"

    for path in (
        activation_path,
        env_policy_path,
        identity_script_path,
        flux_script_path,
        cluster_path,
        observe_workflow_path,
        prod_root_path,
        example_release_path,
        test_release_path,
        bindings_path,
    ):
        require(path.is_file(), f"missing PROD activation file: {path.relative_to(REPO)}")

    activation = load(activation_path)
    logical = activation["spec"]["logicalBoundary"]
    require(activation["metadata"]["environment"] == "prod", "activation contract must target prod")
    require(activation["spec"]["physicalBoundary"]["mode"] == "shared-lab", "PROD Lab activation must reuse the shared physical boundary")
    require(activation["spec"]["physicalBoundary"]["newPaidInfrastructureRequired"] is False, "PROD logical activation must not require new paid infrastructure")
    require(logical["githubEnvironment"] == "prod", "PROD GitHub Environment changed")
    require(logical["desiredStateBranch"] == "gitops/prod", "PROD Desired-State branch changed")
    require(logical["applicationNamespace"] == "cicd-prod", "PROD application namespace changed")
    require(logical["namespaceManagement"] == "arm", "PROD namespace must be ARM-owned")
    require(logical["fluxConfiguration"] == "enterprise-cicd-prod", "PROD Flux configuration changed")

    policy = load(env_policy_path)
    require(policy["metadata"]["environment"] == "prod", "PROD environment policy targets wrong environment")
    require(policy["spec"]["oidcSubject"] == "repo:iwacollection/k3s-gitops:environment:prod", "PROD OIDC subject changed")
    require(policy["spec"]["requiredReviewers"] is True, "PROD must require reviewers")
    require(policy["spec"]["preventSelfReview"] is True, "PROD must prevent self review")
    require(policy["spec"]["longLivedAzureCredentialsAllowed"] is False, "PROD long-lived Azure credentials are forbidden")

    cluster = load(cluster_path)
    require(cluster["metadata"]["environment"] == "prod", "PROD GitOps cluster contract targets wrong environment")
    require(cluster["spec"]["managementMode"] == "gitops-only", "PROD Kubernetes write plane must remain GitOps-only")
    require(cluster["spec"]["directDeployFromCI"] is False, "CI must never directly deploy PROD")
    require(cluster["spec"]["azure"]["namespaceManagement"] == "arm", "PROD cluster namespace management must remain ARM")
    require(cluster["spec"]["azure"]["namespaceOwnership"] == "arm-only-not-flux", "PROD Namespace ownership guard changed")
    require(cluster["spec"]["flux"]["branch"] == "gitops/prod", "PROD Flux must track gitops/prod")
    require(cluster["spec"]["flux"]["configurationName"] == "enterprise-cicd-prod", "PROD Flux configuration name changed")
    require(cluster["spec"]["applicationNamespace"] == "cicd-prod", "PROD cluster namespace changed")
    require(cluster["spec"]["policy"]["imageDigestRequired"] is True, "PROD must require immutable image digests")
    require(cluster["spec"]["policy"]["namespaceManifestForbiddenInFluxRoot"] is True, "PROD Flux root must forbid namespace manifest ownership")

    prod_root = prod_root_path.read_text(encoding="utf-8")
    require("namespace.yaml" not in prod_root, "platform PROD root must not reintroduce namespace.yaml")

    identity_script = identity_script_path.read_text(encoding="utf-8")
    require("APPLY=0" in identity_script and '== "--apply"' in identity_script, "PROD identity bootstrap must default to PLAN ONLY")
    require('IDENTITY_NAME="k3s-gitops-prod-uami"' in identity_script, "PROD identity name changed")
    require('GITHUB_ENVIRONMENT="prod"' in identity_script, "PROD identity must bind GitHub Environment prod")
    require('OIDC_SUBJECT="repo:iwacollection/k3s-gitops:environment:prod"' in identity_script, "PROD identity OIDC subject changed")
    for forbidden in ("Contributor", "Owner", "AcrPush", "RBAC Writer", "RBAC Admin"):
        require(forbidden in identity_script, f"PROD identity bootstrap missing explicit forbidden capability guard: {forbidden}")
    require("Microsoft.ContainerService/managedClusters/apps/deployments/read" in identity_script, "PROD observer must read Deployments")
    require("deployments/write" not in identity_script.lower(), "PROD observer must not get Deployment write")

    flux_script = flux_script_path.read_text(encoding="utf-8")
    require("APPLY=0" in flux_script and '== "--apply"' in flux_script, "PROD Flux bootstrap must default to PLAN ONLY")
    require('APPLICATION_NAMESPACE="cicd-prod"' in flux_script, "PROD Flux bootstrap namespace changed")
    require('BRANCH="gitops/prod"' in flux_script, "PROD Flux bootstrap branch changed")
    require('CONFIG_NAME="enterprise-cicd-prod"' in flux_script, "PROD Flux bootstrap configuration changed")
    require('namespace.yaml' in flux_script and 'ARM/Flux ownership would conflict' in flux_script, "PROD Flux bootstrap must fail closed on Namespace ownership conflict")
    require("az k8s-configuration" not in flux_script, "PROD Flux bootstrap must not depend on the broken k8s-configuration CLI extension")
    require("az rest --method put" in flux_script, "PROD Flux bootstrap must use ARM REST writes")
    require('"adoptionPolicy": "IfIdentical"' in flux_script, "PROD ARM namespace adoption policy changed")
    require('"deletePolicy": "Keep"' in flux_script, "PROD ARM namespace delete policy changed")

    test_release = load(test_release_path)
    prod_example = load(example_release_path)
    require(prod_example["spec"]["from"] == "test" and prod_example["spec"]["to"] == "prod", "PROD example must be TEST -> PROD")
    require(prod_example["spec"]["artifactRepository"] == test_release["spec"]["artifactRepository"], "PROD example must preserve TEST artifact repository")
    require(prod_example["spec"]["artifactDigest"] == test_release["spec"]["artifactDigest"], "PROD example must preserve exact TEST artifact digest")
    require(prod_example["spec"]["sourceReleaseRequest"] == "enterprise-cicd/release-requests/platform-smoke-api-to-test.json", "PROD example lineage must point to TEST ReleaseRequest")

    observe = observe_workflow_path.read_text(encoding="utf-8")
    require("environment: prod" in observe, "PROD Observe must run behind the prod GitHub Environment")
    require("test \"$(jq -r .spec.from \"$REQUEST\")\" = test" in observe, "PROD Observe must enforce TEST source")
    require("test \"$(jq -r .spec.to \"$REQUEST\")\" = prod" in observe, "PROD Observe must enforce PROD target")
    require("sameDigestFromTest:true" in observe, "PROD verification evidence must record same TEST digest")
    require("deployment_create=$CREATE_DEPLOY" in observe and "deployment_patch=$PATCH_DEPLOY" in observe and "deployment_delete=$DELETE_DEPLOY" in observe, "PROD Observe must prove mutation access denied")
    for forbidden in ("kubectl apply", "kubectl create", "kubectl patch", "kubectl delete", "helm upgrade", "helm install"):
        require(forbidden not in observe, f"PROD Observe contains forbidden Kubernetes mutation command: {forbidden}")

    bindings = load(bindings_path)
    prod_binding = bindings["environments"]["prod"]["identities"]["githubOidc"]
    require(prod_binding["environment"] == "prod", "PROD binding expected GitHub Environment changed")
    require(prod_binding["name"] == "k3s-gitops-prod-uami", "PROD binding identity name changed")
    # client/principal IDs are intentionally allowed to remain null before privileged activation.

    print("PROD activation static safety contract valid.")
    print(f"same TEST digest prepared for PROD example: {prod_example['spec']['artifactDigest']}")
    print("namespace ownership: ARM-only; Flux workload root excludes namespace.yaml")
    print("Kubernetes write plane: Flux only; PROD observer mutation access forbidden")


if __name__ == "__main__":
    main()
