#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
SERVICES = REPO / "enterprise-cicd" / "iac-catalog" / "services"
BINDINGS = REPO / "enterprise-cicd" / "contracts" / "iac-runtime-bindings.json"
STATE_CONTRACT = REPO / "enterprise-cicd" / "contracts" / "state-contract.json"
FOUNDATION_DESIRED = REPO / "enterprise-cicd" / "contracts" / "iac-platform-foundation.json"
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
BILLABLE = WORKLOAD | {"load-balancer", "vpn-gateway"}


def require(ok: bool, message: str) -> None:
    if not ok:
        raise SystemExit(message)


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def text(path: Path) -> str:
    require(path.is_file(), f"missing required file: {path.relative_to(REPO)}")
    return path.read_text(encoding="utf-8")


def require_tokens(path: Path, tokens: tuple[str, ...]) -> str:
    value = text(path)
    for token in tokens:
        require(token in value, f"{path.name}: missing contract token {token!r}")
    return value


def main() -> None:
    active: dict[str, dict] = {}
    for directory in SERVICES.iterdir():
        catalog_path = directory / "v1" / "catalog.json"
        if directory.is_dir() and not directory.name.startswith("_") and catalog_path.is_file():
            catalog = load(catalog_path)
            if catalog.get("lifecycle") == "active":
                active[directory.name] = catalog

    require(set(active) == set(EXPECTED), f"active Catalog set is not fully governed: {sorted(active)}")
    for service, apply_mode in EXPECTED.items():
        catalog = active[service]
        require(catalog.get("applyMode") == apply_mode, f"{service}: applyMode must be {apply_mode}")
        require(bool(catalog.get("riskClass")), f"{service}: riskClass required")
        expected_billing = "billable" if service in BILLABLE else "none"
        require(catalog.get("billingImpact") == expected_billing, f"{service}: billingImpact must be {expected_billing}")
        require((REPO / catalog["rootStack"]).is_dir(), f"{service}: root stack missing")

    canonical = require_tokens(
        WORKFLOWS / "iac-request-apply.yml",
        (
            "workflow_dispatch:", "standard-oidc", "protected-edge-oidc",
            "dedicated-iam-oidc", "protected-workload-oidc", "confirm_billable",
            "environment: ${{ needs.resolve.outputs.github_environment }}", "id-token: write",
            "-lock=true", "apply.tfplan", "'delete' in x['actions']",
            "Require post-Apply Terraform convergence", "-detailed-exitcode",
            'postApplyPlan":"no-changes', "azure-resource-verification.jsonl",
        ),
    )
    for service in EXPECTED:
        require(f"'{service}'" in canonical, f"canonical Apply does not route {service}")

    require_tokens(WORKFLOWS / "iac-request-dev-apply.yml", ("managed-identity", "network", "apply.tfplan", "destructive automatic Apply is forbidden"))
    require_tokens(WORKFLOWS / "iac-request-test-prod-apply.yml", ("managed-identity", "network", "apply.tfplan", "destructive Apply forbidden"))
    require_tokens(WORKFLOWS / "iac-request-protected-capability-apply.yml", ("load-balancer", "vpn-gateway", "iam-role-binding", "apply.tfplan", "destructive protected Apply is forbidden"))
    require_tokens(
        WORKFLOWS / "iac-request-workload-capability-apply.yml",
        ("acr", "storage", "key-vault", "service-bus", "managed-redis", "postgresql-flexible", "protected-workload-oidc", "confirm_billable", "apply.tfplan", "Post-Apply Terraform Plan still contains changes"),
    )
    require_tokens(
        WORKFLOWS / "iac-platform-foundation.yml",
        ("connectivity", "observability", "iac-platform-foundation.json", "--scope platform", "--environment", "-lock=true", "postApplyPlan\":\"no-changes", "azureReadback"),
    )

    scripts = [
        ACTIVATION / "activate-iac-delivery-capabilities.sh",
        ACTIVATION / "activate-iac-edge-network-capability.sh",
        ACTIVATION / "activate-iac-iam-capability.sh",
        ACTIVATION / "activate-iac-workload-services-capability.sh",
        ACTIVATION / "activate-iac-platform-foundation-capability.sh",
    ]
    for script in scripts:
        require(script.is_file(), f"activation script missing: {script.relative_to(REPO)}")
        subprocess.run(["bash", "-n", str(script)], check=True)

    delivery = text(scripts[0])
    require("WORKLOAD_SCRIPT=" in delivery and "three isolated protected Apply planes" in delivery, "unified delivery activation does not include Workload Apply")

    workload_script = text(scripts[3])
    role_body = workload_script.split('ROLE_BODY="$(cat <<EOF', 1)[1].split('\nEOF\n)"', 1)[0]
    for service in WORKLOAD:
        require(service in workload_script, f"workload activation missing {service}")
    for forbidden in (
        "Microsoft.Authorization/roleAssignments/write",
        "Microsoft.Network/*",
        "Microsoft.Storage/storageAccounts/listkeys/action",
        "Microsoft.ContainerRegistry/registries/listCredentials/action",
        "Microsoft.ServiceBus/namespaces/authorizationRules/listkeys/action",
        "Microsoft.KeyVault/vaults/secrets/getSecret/action",
    ):
        require(forbidden not in role_body, f"Workload Apply role leaked {forbidden}")
    require('"dataActions": []' in role_body, "Workload Apply must not receive service data-plane permissions")

    foundation_script = text(scripts[4])
    foundation_role = foundation_script.split('ROLE_BODY="$(cat <<EOF', 1)[1].split('\nEOF\n)"', 1)[0]
    for required in (
        "Microsoft.Network/virtualNetworks/write",
        "Microsoft.Network/privateDnsZones/write",
        "Microsoft.OperationalInsights/workspaces/write",
        "Microsoft.Monitor/accounts/write",
    ):
        require(required in foundation_role, f"Foundation Apply role missing {required}")
    for forbidden in ("publicIPAddresses/", "natGateways/", "loadBalancers/", "virtualNetworkGateways/", "privateEndpoints/write", "roleAssignments/write"):
        require(forbidden not in foundation_role, f"Foundation Apply role leaked {forbidden}")

    binding = load(BINDINGS)
    require(binding.get("version") == 3, "IaC runtime binding schema must be v3")
    require(binding["state"].get("authentication") == "MicrosoftEntraID", "state authentication must be Entra ID")
    require(binding["state"].get("sharedKeyAccess") is False, "state Shared Key must remain disabled")
    for env in ("dev", "test", "prod"):
        runtime = binding["environments"][env]
        for plane in ("foundation", "edge", "iam", "workload"):
            require(plane in runtime, f"{env}: missing {plane} plane")
        require(runtime["foundation"].get("githubEnvironment") == f"iac-{env}-foundation-apply", f"{env}: Foundation Environment mismatch")
        workload = runtime["workload"]
        require(workload.get("githubEnvironment") == f"iac-{env}-workload-apply", f"{env}: Workload Environment mismatch")
        require(set(workload.get("supportedServices", [])) == WORKLOAD, f"{env}: Workload service coverage mismatch")

    desired = load(FOUNDATION_DESIRED)
    require(set(desired.get("environments", {})) == {"dev", "test", "prod"}, "Foundation desired state must cover dev/test/prod")
    for env, config in desired["environments"].items():
        conn=config["connectivity"]; obs=config["observability"]
        require(conn["nat_gateway"] is None and conn["network_security_groups"] == {} and conn["route_tables"] == {}, f"{env}: foundation must not include paid/broad network add-ons")
        require({"snet-private-endpoints", "snet-postgresql"} <= set(conn["subnets"]), f"{env}: required shared subnets missing")
        require(obs["daily_quota_gb"] <= 1, f"{env}: observability daily quota guard widened")

    state = load(STATE_CONTRACT)
    require(state.get("version") == "v2", "state contract must be v2")
    require(set(state.get("environment_scoped_platform_stacks", [])) >= {"connectivity", "observability"}, "foundation platform stacks must be environment-scoped")
    require(state.get("platform_environment_key_pattern") == "platform/{environment}/{stack}.tfstate", "foundation state key pattern changed")

    print("IaC APPLY COVERAGE: PASSED")
    print(f"active_catalogs={len(active)}")
    print("all_active_catalogs_have_apply_mode=true")
    print("apply_planes=standard,foundation,edge,iam,workload")
    print("canonical_apply=exact-saved-plan,state-lock,no-delete,post-apply-no-changes")
    print("platform_foundation_state=environment-isolated")


if __name__ == "__main__":
    main()
