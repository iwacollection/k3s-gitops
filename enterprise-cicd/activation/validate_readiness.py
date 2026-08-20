from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent
DEV_CLUSTER_BINDING = ROOT / "gitops" / "clusters" / "aks-automatic-lab" / "cluster.json"
DEV_DESIRED_STATE_BRANCH = "gitops/dev"

EXPECTED_ENVIRONMENTS = {"dev", "test", "prod"}
EXPECTED_DIAGNOSTIC_SERVICES = {
    "storage-blob",
    "key-vault",
    "service-bus",
    "managed-redis-database",
}
FORBIDDEN_KUBERNETES_WRITES = re.compile(
    r"\b(?:kubectl\s+(?:apply|create|delete|patch|replace|scale|edit|label|annotate|cordon|drain|taint)|"
    r"helm\s+(?:install|upgrade|uninstall|rollback))\b",
    re.IGNORECASE,
)
ALLOWED_EXPLICIT_BOOTSTRAP_WORKFLOWS = {"azure-aks-bootstrap-launcher.yml"}


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def check_environment_bindings(report: dict) -> bool:
    data = load_json(ROOT / "contracts" / "environment-bindings.json")
    environments = data.get("environments", {})
    if set(environments) != EXPECTED_ENVIRONMENTS:
        raise SystemExit("environment-bindings.json must define exactly dev/test/prod")

    prod_dba_ready = False
    for env in sorted(EXPECTED_ENVIRONMENTS):
        binding = environments[env]
        network = binding.get("network", {})
        observability = binding.get("observability", {})
        identities = binding.get("identities", {})
        for key in ("resourceGroup", "virtualNetwork", "privateEndpointSubnet", "postgresDelegatedSubnet", "dnsZones"):
            if not network.get(key):
                raise SystemExit(f"{env}: missing network.{key}")
        for key in ("resourceGroup", "logAnalyticsWorkspace", "azureMonitorWorkspace"):
            if not observability.get(key):
                raise SystemExit(f"{env}: missing observability.{key}")
        dba = identities.get("postgresqlDba") or {}
        if dba.get("principalType") != "Group":
            raise SystemExit(f"{env}: postgresqlDba principalType must be Group")
        if env == "prod":
            prod_dba_ready = bool(dba.get("objectId") and dba.get("principalName"))

    report["environmentBindings"] = "valid"
    report["postgresqlProdDbaBindingReady"] = prod_dba_ready
    return prod_dba_ready


def check_diagnostics(report: dict) -> None:
    data = load_json(ROOT / "contracts" / "diagnostic-categories.json")
    services = data.get("services", {})
    if set(services) != EXPECTED_DIAGNOSTIC_SERVICES:
        raise SystemExit("diagnostic-categories.json service set does not match the V1 governed set")
    for name, contract in services.items():
        if not contract.get("resourceType"):
            raise SystemExit(f"{name}: resourceType is required")
        enabled = (
            len(contract.get("logCategories", []))
            + len(contract.get("logCategoryGroups", []))
            + len(contract.get("metricCategories", []))
        )
        if enabled == 0:
            raise SystemExit(f"{name}: at least one diagnostic log/group/metric must be configured")
    report["diagnosticContracts"] = "valid"


def check_build_images(report: dict) -> None:
    data = load_json(ROOT / "build-images" / "versions.json")
    images = data.get("images", {})
    expected = {"java21-maven:v1", "python-uv:v1", "go-builder:v1", "cpp-cmake-conan:v1"}
    if set(images) != expected:
        raise SystemExit("build-images/versions.json must define the four V1 platform images")
    if data.get("policy", {}).get("mutableTagAllowed") is not False:
        raise SystemExit("platform build images must forbid mutable tags")
    if data.get("policy", {}).get("promotionByDigest") is not True:
        raise SystemExit("platform build images must promote by digest")
    for key, spec in images.items():
        context = ROOT.parent / spec["context"]
        dockerfile = context / spec.get("dockerfile", "Dockerfile")
        if not dockerfile.is_file():
            raise SystemExit(f"{key}: Dockerfile not found at {dockerfile}")
    report["buildImageContracts"] = "valid"


def check_dev_cluster_binding(report: dict) -> None:
    if not DEV_CLUSTER_BINDING.is_file():
        raise SystemExit("DEV AKS cluster binding is missing")
    binding = load_json(DEV_CLUSTER_BINDING)
    if binding.get("kind") != "ClusterBinding" or binding.get("metadata", {}).get("environment") != "dev":
        raise SystemExit("aks-automatic-lab must be a DEV ClusterBinding")
    azure = binding.get("spec", {}).get("azure", {})
    flux = binding.get("spec", {}).get("flux", {})
    if not azure.get("resourceGroup") or not azure.get("clusterName"):
        raise SystemExit("DEV ClusterBinding must contain Azure resourceGroup and clusterName")
    if flux.get("branch") != DEV_DESIRED_STATE_BRANCH:
        raise SystemExit(f"DEV Flux binding must reconcile the protected {DEV_DESIRED_STATE_BRANCH} branch")
    dev_kustomizations = [
        item for item in flux.get("kustomizations", [])
        if str(item.get("path", "")).endswith("/environments/dev")
    ]
    if not dev_kustomizations:
        raise SystemExit("DEV ClusterBinding must include the DEV environment kustomization")
    report["devClusterBinding"] = {
        "name": binding["metadata"]["name"],
        "resourceGroup": azure["resourceGroup"],
        "clusterName": azure["clusterName"],
        "fluxBranch": flux["branch"],
    }


def check_flux_only_write_plane(report: dict) -> None:
    violations: list[str] = []
    workflow_dir = REPO / ".github" / "workflows"
    for path in sorted(workflow_dir.glob("*.yml")):
        if path.name in ALLOWED_EXPLICIT_BOOTSTRAP_WORKFLOWS:
            continue
        text = path.read_text(encoding="utf-8")
        for match in FORBIDDEN_KUBERNETES_WRITES.finditer(text):
            violations.append(f"{path.name}: {match.group(0)}")
    if violations:
        raise SystemExit("Direct Kubernetes write path detected outside explicit Flux bootstrap: " + "; ".join(violations))

    activation = workflow_dir / "azure-dev-smoke-deploy.yml"
    promotion = workflow_dir / "gitops-promotion.yml"
    if not activation.is_file() or not promotion.is_file():
        raise SystemExit("GitOps activation/promotion workflows are missing")
    activation_text = activation.read_text(encoding="utf-8")
    promotion_text = promotion.read_text(encoding="utf-8")
    if "gitops-promotion.yml" not in activation_text or "reusable-cd-post-deploy-v1.yml" not in activation_text:
        raise SystemExit("DEV activation must route through GitOps promotion and post-deploy observation")
    if "aks-automatic-lab/cluster.json" not in activation_text:
        raise SystemExit("DEV activation must use the platform-owned LAB ClusterBinding")
    if "*.example.json" not in activation_text or "*.example.json" not in promotion_text:
        raise SystemExit("Real promotion workflows must explicitly reject example Release Requests")
    if 'BASE_BRANCH="gitops/dev"' not in promotion_text:
        raise SystemExit("DEV promotion must target the protected gitops/dev desired-state branch")
    report["kubernetesWritePlane"] = "flux-only"
    report["exampleReleasePromotion"] = "forbidden"


def check_postgresql_policy(prod_dba_ready: bool, report: dict) -> None:
    policy = load_json(ROOT / "iac-catalog" / "services" / "postgresql-flexible" / "v1" / "policy.json")
    prod_policy = policy.get("prod", {})
    prod_enabled = bool(prod_policy.get("enabled"))
    if not prod_dba_ready and prod_enabled:
        raise SystemExit("PostgreSQL PROD catalog cannot be enabled while the real Entra DBA binding is absent")
    if not prod_enabled and not prod_policy.get("activationPolicy"):
        raise SystemExit("Disabled PostgreSQL PROD policy must carry a predeclared activationPolicy")
    report["postgresqlProdCatalogEnabled"] = prod_enabled
    report["postgresqlProdActivationReady"] = prod_dba_ready and prod_enabled


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate enterprise platform activation readiness.")
    parser.add_argument("--strict-external", action="store_true", help="Fail when external production identity bindings are still absent.")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    report: dict[str, object] = {"schemaVersion": 1, "codeReady": True}
    prod_dba_ready = check_environment_bindings(report)
    check_diagnostics(report)
    check_build_images(report)
    check_dev_cluster_binding(report)
    check_flux_only_write_plane(report)
    check_postgresql_policy(prod_dba_ready, report)

    blockers: list[str] = []
    if not prod_dba_ready:
        blockers.append("real PROD PostgreSQL Entra DBA Group objectId/principalName not configured")
    if not report["postgresqlProdCatalogEnabled"]:
        blockers.append("PostgreSQL PROD catalog policy remains intentionally disabled")
    report["externalActivationBlockers"] = blockers
    report["activationReady"] = not blockers

    rendered = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    print(rendered, end="")

    if args.strict_external and blockers:
        raise SystemExit("Strict activation readiness failed: " + "; ".join(blockers))


if __name__ == "__main__":
    main()
