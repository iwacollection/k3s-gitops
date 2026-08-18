from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def load(path: Path):
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def main() -> None:
    policy = load(ROOT / "gitops" / "contracts" / "gitops-policy.json")
    spec = policy["spec"]
    require(spec["deploymentMode"] == "pull", "GitOps must remain pull based")
    require(spec["directCiClusterWrite"] is False, "CI must not directly write Kubernetes")
    require(spec["artifactIdentity"] == "sha256-digest", "GitOps must promote immutable digests")
    require(spec["rebuildDuringPromotion"] is False, "promotion must not rebuild artifacts")
    require(spec["productionApprovalRequired"] is True, "production approval is required")
    require(spec["productionLockRequired"] is True, "production serialization/lock is required")
    require(spec["allowedTransitions"] == ["build->dev", "dev->test", "test->prod"], "unexpected environment promotion graph")

    release_schema = load(ROOT / "release-requests" / "release.schema.json")
    required_release_fields = set(release_schema["properties"]["spec"]["required"])
    require("artifactRepository" in required_release_fields, "release request must include artifactRepository")
    require("artifactDigest" in required_release_fields, "release request must include artifactDigest")
    require("changeReason" in required_release_fields, "release request must include changeReason")

    rolling = load(ROOT / "release-catalog" / "rolling" / "rolling-v1" / "profile.json")
    canary = load(ROOT / "release-catalog" / "canary" / "canary-v1" / "profile.json")
    blue_green = load(ROOT / "release-catalog" / "blue-green" / "blue-green-v1" / "profile.json")
    require(rolling["spec"]["execution"]["ready"] is True, "rolling executor must remain available")
    require(rolling["spec"]["execution"]["engine"] == "kubernetes-deployment", "unexpected rolling executor")
    require(canary["spec"]["execution"]["ready"] is False, "canary must stay blocked until a progressive delivery controller exists")
    require(blue_green["spec"]["execution"]["ready"] is False, "blue-green must stay blocked until a traffic-switch controller exists")

    cluster = load(ROOT / "gitops" / "clusters" / "aks-automatic-lab" / "cluster.json")
    require(cluster["spec"]["azure"]["clusterName"] == "k8s-test-cicd", "lab cluster binding changed unexpectedly")
    require(cluster["spec"]["azure"]["clusterType"] == "managedClusters", "AKS must use managedClusters type")
    flux = cluster["spec"]["flux"]
    require(flux["extension"] == "microsoft.flux", "AKS GitOps must use microsoft.flux")
    kustomizations = {item["name"]: item for item in flux["kustomizations"]}
    require(kustomizations["infra"]["prune"] is True, "infra pruning must be enabled")
    require(kustomizations["apps-dev"]["dependsOn"] == ["infra"], "apps-dev must depend on infra")

    for environment in ("dev", "test", "prod"):
        env_dir = ROOT / "gitops" / "environments" / environment
        require((env_dir / "kustomization.yaml").is_file(), f"missing {environment} Kustomize root")
        require((env_dir / "namespace.yaml").is_file(), f"missing {environment} namespace manifest")
        namespace_text = (env_dir / "namespace.yaml").read_text(encoding="utf-8")
        require(f"name: cicd-{environment}" in namespace_text, f"unexpected namespace for {environment}")

    app_base = ROOT / "gitops" / "apps" / "go-smoke" / "base"
    require((app_base / "kustomization.yaml").is_file(), "go-smoke GitOps base is missing")
    deployment = (app_base / "deployment.yaml").read_text(encoding="utf-8")
    require("image: platform.local/go-smoke:placeholder" in deployment, "go-smoke base must use platform image placeholder")

    promotion_workflow = (ROOT.parent / ".github" / "workflows" / "gitops-promotion.yml").read_text(encoding="utf-8")
    forbidden = ("kubectl apply", "helm upgrade", "helm install", "az aks get-credentials")
    for token in forbidden:
        require(token not in promotion_workflow, f"GitOps promotion workflow contains direct deployment command: {token}")
    require("gh pr create" in promotion_workflow, "promotion workflow must create a GitOps PR")
    require("kubectl kustomize" in promotion_workflow, "promotion workflow must validate rendered desired state")

    bootstrap = (ROOT / "gitops" / "clusters" / "aks-automatic-lab" / "bootstrap-flux-aks.sh").read_text(encoding="utf-8")
    require("--apply" in bootstrap, "Flux bootstrap must require explicit apply mode")
    require("PLAN ONLY" in bootstrap, "Flux bootstrap must default to plan-only mode")
    require("APPLY-FLUX" in bootstrap, "Flux bootstrap must require an interactive confirmation")

    print("GitOps platform contracts validated.")


if __name__ == "__main__":
    main()
