#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
SERVICES = REPO / "enterprise-cicd" / "iac-catalog" / "services"
BINDINGS = REPO / "enterprise-cicd" / "contracts" / "iac-runtime-bindings.json"
ACTIVATION = REPO / "enterprise-cicd" / "activation" / "iac"
WORKFLOWS = REPO / ".github" / "workflows"

EXPECTED = {
    "managed-identity": "standard-oidc",
    "network": "standard-oidc",
    "iam-role-binding": "dedicated-iam-oidc",
    "load-balancer": "protected-edge-oidc",
    "vpn-gateway": "protected-edge-oidc",
    "acr": "protected-workload-oidc",
    "storage": "protected-workload-oidc",
    "key-vault": "protected-workload-oidc",
    "service-bus": "protected-workload-oidc",
    "managed-redis": "protected-workload-oidc",
    "postgresql-flexible": "protected-workload-oidc",
}

WORKLOAD = {"acr", "storage", "key-vault", "service-bus", "managed-redis", "postgresql-flexible"}
BILLABLE = {"acr", "storage", "key-vault", "service-bus", "managed-redis", "postgresql-flexible", "load-balancer", "vpn-gateway"}


def fail(message: str) -> None:
    raise SystemExit(message)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def require_tokens(path: Path, tokens: tuple[str, ...]) -> str:
    require(path.is_file(), f"missing Apply runtime: {path.relative_to(REPO)}")
    text = path.read_text(encoding="utf-8")
    for token in tokens:
        require(token in text, f"{path.name}: missing Apply contract token {token!r}")
    return text


def main() -> None:
    catalogs: dict[str, dict] = {}
    for service_dir in sorted(SERVICES.iterdir()):
        if not service_dir.is_dir() or service_dir.name.startswith("_"):
            continue
        catalog_path = service_dir / "v1" / "catalog.json"
        if not catalog_path.is_file():
            continue
        catalog = load(catalog_path)
        if catalog.get("lifecycle") != "active":
            continue
        catalogs[service_dir.name] = catalog

    require(set(catalogs) == set(EXPECTED), f"active Catalog coverage changed: active={sorted(catalogs)}, expected={sorted(EXPECTED)}")
    for service, expected_mode in EXPECTED.items():
        catalog = catalogs[service]
        require(catalog.get("applyMode") == expected_mode, f"{service}: applyMode must be {expected_mode}")
        require(bool(catalog.get("riskClass")), f"{service}: active Catalog must declare riskClass")
        require(bool(catalog.get("billingImpact")), f"{service}: active Catalog must declare billingImpact")
        if service in BILLABLE:
            require(catalog["billingImpact"] == "billable", f"{service}: must be marked billable")
        else:
            require(catalog["billingImpact"] == "none", f"{service}: expected billingImpact=none")
        require(Path(REPO / catalog["rootStack"]).is_dir(), f"{service}: rootStack missing")

    canonical = require_tokens(
        WORKFLOWS / "iac-request-apply.yml",
        (
            "workflow_dispatch:",
            "standard-oidc",
            "protected-edge-oidc",
            "dedicated-iam-oidc",
            "protected-workload-oidc",
            "confirm_billable",
            "environment: ${{ needs.resolve.outputs.github_environment }}",
            "id-token: write",
            "-lock=true",
            "apply.tfplan",
            "'delete' in x['actions']",
            "Require post-Apply Terraform convergence",
            "-detailed-exitcode",
            "postApplyPlan\":\"no-changes",
            "azure-resource-verification.jsonl",
        ),
    )
    for service in EXPECTED:
        require(f"'{service}'" in canonical, f"canonical Apply does not route service={service}")

    standard_dev = require_tokens(
        WORKFLOWS / "iac-request-dev-apply.yml",
        ("managed-identity", "network", "apply.tfplan", "destructive automatic Apply is forbidden"),
    )
    standard_promoted = require_tokens(
        WORKFLOWS / "iac-request-test-prod-apply.yml",
        ("managed-identity", "network", "apply.tfplan", "destructive Apply forbidden"),
    )
    protected = require_tokens(
        WORKFLOWS / "iac-request-protected-capability-apply.yml",
        ("load-balancer", "vpn-gateway", "iam-role-binding", "apply.tfplan", "destructive protected Apply is forbidden"),
    )
    workload = require_tokens(
        WORKFLOWS / "iac-request-workload-capability-apply.yml",
        (
            "acr", "storage", "key-vault", "service-bus", "managed-redis", "postgresql-flexible",
            "protected-workload-oidc", "confirm_billable", "apply.tfplan", "Post-Apply Terraform Plan still contains changes",
        ),
    )
    require("terraform apply" not in standard_dev or "apply.tfplan" in standard_dev, "DEV standard Apply must consume a saved plan")
    require("terraform apply" not in standard_promoted or "apply.tfplan" in standard_promoted, "promoted standard Apply must consume a saved plan")
    require("terraform apply" not in protected or "apply.tfplan" in protected, "protected Apply must consume a saved plan")
    require("terraform apply" not in workload or "apply.tfplan" in workload, "workload Apply must consume a saved plan")

    delivery = ACTIVATION / "activate-iac-delivery-capabilities.sh"
    edge = ACTIVATION / "activate-iac-edge-network-capability.sh"
    iam = ACTIVATION / "activate-iac-iam-capability.sh"
    workload_activation = ACTIVATION / "activate-iac-workload-services-capability.sh"
    for script in (delivery, edge, iam, workload_activation):
        require(script.is_file(), f"missing activation script: {script.relative_to(REPO)}")
        subprocess.run(["bash", "-n", str(script)], check=True)
    delivery_text = delivery.read_text(encoding="utf-8")
    require("WORKLOAD_SCRIPT=" in delivery_text, "unified delivery activation must include workload plane")
    require("three isolated protected Apply planes" in delivery_text, "delivery activation description is stale")

    workload_text = workload_activation.read_text(encoding="utf-8")
    for service in sorted(WORKLOAD):
        require(service in workload_text, f"workload activation missing service {service}")
    for forbidden in (
        "Microsoft.Authorization/roleAssignments/write",
        "Microsoft.Network/*",
        "Microsoft.Storage/storageAccounts/listkeys/action",
        "Microsoft.ContainerRegistry/registries/listCredentials/action",
        "Microsoft.ServiceBus/namespaces/authorizationRules/listkeys/action",
        "Microsoft.KeyVault/vaults/secrets/getSecret/action",
    ):
        # Forbidden strings may appear only inside the script's self-test block, never in ROLE_BODY actions.
        role_body = workload_text.split('ROLE_BODY="$(cat <<EOF', 1)[1].split('\nEOF\n)"', 1)[0]
        require(forbidden not in role_body, f"workload role leaked forbidden permission {forbidden}")

    binding = load(BINDINGS)
    require(binding.get("version") == 3, "IaC runtime binding schema must be v3")
    require(binding["state"]["authentication"] == "MicrosoftEntraID" and binding["state"]["sharedKeyAccess"] is False, "state must remain Entra-only")
    for env in ("dev", "test", "prod"):
        runtime = binding["environments"][env]
        for plane in ("edge", "iam", "workload"):
            require(plane in runtime, f"{env}: missing {plane} Apply plane")
        require(runtime["workload"]["githubEnvironment"] == f"iac-{env}-workload-apply", f"{env}: workload Environment mismatch")
        require(set(runtime["workload"]["supportedServices"]) == WORKLOAD, f"{env}: workload service coverage mismatch")

    print("IaC APPLY COVERAGE: PASSED")
    print(f"active_catalogs={len(catalogs)}")
    print("apply_modes=standard-oidc,dedicated-iam-oidc,protected-edge-oidc,protected-workload-oidc")
    print("canonical_apply=exact-saved-plan + state-lock + no-delete + post-apply-no-changes")
    print("workload_services=" + ",".join(sorted(WORKLOAD)))


if __name__ == "__main__":
    main()
