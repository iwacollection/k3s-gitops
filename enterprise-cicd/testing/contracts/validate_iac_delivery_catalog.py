#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
ROOT = REPO / "enterprise-cicd"
CATALOG = ROOT / "iac-catalog"
RENDERER = CATALOG / "render_request.py"
SERVICES = CATALOG / "services"
ACTIVATION = ROOT / "activation" / "iac"
BINDINGS = ROOT / "contracts" / "iac-runtime-bindings.json"
PROTECTED_APPLY = REPO / ".github" / "workflows" / "iac-request-protected-capability-apply.yml"

NEW_SERVICES = {
    "iam-role-binding": "privileged",
    "load-balancer": "network-edge",
    "vpn-gateway": "network-edge",
}
APPROVED_IAM_ROLES = {"Reader", "AcrPull", "Storage Blob Data Reader", "Key Vault Secrets User"}
APPROVED_IAM_ROLE_IDS = {
    "acdd72a7-3385-48ef-bd42-f606fba81ae7",
    "7f951dda-4ed3-4680-a7ca-43fe172d538d",
    "2a2b9908-6ea1-4ae2-8e65-a410df84e7d1",
    "4633458b-17de-408a-b874-0445c86b69e6",
}
FORBIDDEN_IAM_ROLES = {
    "Owner", "Contributor", "User Access Administrator",
    "Role Based Access Control Administrator", "Network Contributor",
}
SECRET_KEYS = {"sharedkey", "sharedsecret", "psk", "password", "secret"}


def fail(message: str) -> None:
    raise SystemExit(message)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def render(request: Path, expect_success: bool = True) -> dict | None:
    with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as out:
        output = Path(out.name)
    proc = subprocess.run(
        [sys.executable, str(RENDERER), "--request", str(request), "--output", str(output)],
        cwd=REPO, text=True, capture_output=True,
    )
    if expect_success and proc.returncode != 0:
        fail(f"renderer failed for {request}: {proc.stderr or proc.stdout}")
    if not expect_success and proc.returncode == 0:
        fail(f"renderer unexpectedly accepted forbidden request {request}")
    data = load(output) if proc.returncode == 0 else None
    output.unlink(missing_ok=True)
    return data


def negative_variant(service: str, mutate) -> None:
    source = load(SERVICES / service / "v1" / "request.example.json")
    mutate(source)
    with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as fh:
        json.dump(source, fh)
        path = Path(fh.name)
    try:
        render(path, expect_success=False)
    finally:
        path.unlink(missing_ok=True)


def heredoc(text: str, variable: str) -> str:
    marker = f'{variable}="$(cat <<EOF\n'
    require(marker in text, f"missing {variable} heredoc")
    start = text.index(marker) + len(marker)
    end = text.index("\nEOF\n)", start)
    return text[start:end]


def microsoft_actions(role_body: str) -> set[str]:
    return {
        value for value in re.findall(r'"(Microsoft\.[^"]+)"', role_body)
        if value.endswith(("/read", "/write", "/delete", "/action", "/*"))
    }


def validate_runtime() -> None:
    edge_path = ACTIVATION / "activate-iac-edge-network-capability.sh"
    iam_path = ACTIVATION / "activate-iac-iam-capability.sh"
    foundation_path = ACTIVATION / "activate-iac-network-foundation-capability.sh"
    for path in (edge_path, iam_path, foundation_path, PROTECTED_APPLY, BINDINGS):
        require(path.is_file(), f"missing delivery runtime file: {path.relative_to(REPO)}")
    for script in (edge_path, iam_path, foundation_path):
        subprocess.run(["bash", "-n", str(script)], check=True)

    edge = edge_path.read_text(encoding="utf-8")
    require('APPLY=0' in edge and '--apply' in edge, "Edge activation must be plan-only by default")
    require('k3s-gitops-iac-edge-apply-${ENVIRONMENT}-uami' in edge, "Edge must use a dedicated UAMI")
    edge_actions = microsoft_actions(heredoc(edge, "ROLE_BODY"))
    for required in {
        "Microsoft.Network/publicIPAddresses/write",
        "Microsoft.Network/loadBalancers/write",
        "Microsoft.Network/loadBalancers/backendAddressPools/write",
        "Microsoft.Network/loadBalancers/probes/write",
        "Microsoft.Network/loadBalancers/loadBalancingRules/write",
        "Microsoft.Network/virtualNetworkGateways/write",
    }:
        require(required in edge_actions, f"Edge role missing {required}")
    for forbidden in {
        "Microsoft.Network/*",
        "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/write",
        "Microsoft.Network/natGateways/write",
        "Microsoft.Network/applicationGateways/write",
        "Microsoft.Network/connections/write",
        "Microsoft.Authorization/roleAssignments/write",
    }:
        require(forbidden not in edge_actions, f"Edge role leaked forbidden action {forbidden}")
    require(not any("virtualNetworkPeerings" in x for x in edge_actions), "Edge role must not manage peering")
    require(not any("natGateways" in x for x in edge_actions), "Edge role must not manage NAT Gateway")
    require(not any("applicationGateways" in x for x in edge_actions), "Edge role must not manage Application Gateway")
    require(not any("connections/write" in x for x in edge_actions), "VPN S2S connection write must stay outside v1")

    foundation = foundation_path.read_text(encoding="utf-8")
    foundation_actions = microsoft_actions(heredoc(foundation, "ROLE_BODY"))
    require("Microsoft.Network/virtualNetworks/write" in foundation_actions, "network foundation VNet write missing")
    require("Microsoft.Network/virtualNetworks/subnets/write" in foundation_actions, "network foundation subnet write missing")
    for fragment in ("publicIPAddresses", "natGateways", "virtualNetworkPeerings", "loadBalancers", "virtualNetworkGateways", "applicationGateways"):
        require(not any(fragment in x for x in foundation_actions), f"standard network foundation leaked {fragment}")

    iam = iam_path.read_text(encoding="utf-8")
    require('APPLY=0' in iam and '--apply' in iam, "IAM activation must be plan-only by default")
    require('k3s-gitops-iac-iam-apply-${ENVIRONMENT}-uami' in iam, "IAM must use a dedicated UAMI")
    require('RBAC_ADMIN_ROLE_ID="f58310d9-a9f6-439a-9e8d-f62e7b41a168"' in iam, "conditioned RBAC Administrator role missing")
    require('conditionVersion' in iam and "'2.0'" in iam, "IAM condition version 2.0 missing")
    condition_line = next(line for line in iam.splitlines() if line.startswith('CONDITION='))
    for token in ("roleAssignments/write", "roleAssignments/delete", "RoleDefinitionId", "PrincipalType", "ServicePrincipal", "${ALLOWED_ROLE_IDS}"):
        require(token in condition_line, f"IAM ABAC condition missing {token}")
    for role_id in APPROVED_IAM_ROLE_IDS:
        require(role_id in iam, f"IAM role ID allowlist missing {role_id}")

    binding = load(BINDINGS)
    require(binding["version"] == 2, "IaC binding schema must be v2")
    require(binding["state"]["authentication"] == "MicrosoftEntraID", "state must remain Entra-only")
    require(binding["state"]["sharedKeyAccess"] is False, "state Shared Key must remain disabled")
    for env in ("dev", "test", "prod"):
        runtime = binding["environments"][env]
        require("networkFoundation" in runtime and "edge" in runtime and "iam" in runtime, f"{env}: capability planes incomplete")
        require(runtime["edge"]["githubEnvironment"] == f"iac-{env}-edge-apply", f"{env}: Edge Environment mismatch")
        require(runtime["iam"]["githubEnvironment"] == f"iac-{env}-iam-apply", f"{env}: IAM Environment mismatch")

    workflow = PROTECTED_APPLY.read_text(encoding="utf-8")
    for token in (
        "workflow_dispatch:", "confirm_billable:",
        "service in {'load-balancer', 'vpn-gateway'}", "service == 'iam-role-binding'",
        "environment: ${{ needs.resolve.outputs.github_environment }}", "id-token: write",
        "ARM_RESOURCE_PROVIDER_REGISTRATIONS: 'none'", "-lock=true",
        "'delete' in item['actions']", "/tmp/iac-protected-apply/apply.tfplan",
        "vpn-connection list", "siteConnections':0",
    ):
        require(token in workflow, f"protected Apply contract missing {token}")


def main() -> None:
    for service, risk_class in NEW_SERVICES.items():
        root = SERVICES / service / "v1"
        for name in ("catalog.json", "defaults.json", "policy.json", "request.schema.json", "request.example.json", "README.md"):
            require((root / name).is_file(), f"{service}: missing {name}")
        catalog = load(root / "catalog.json")
        require(catalog.get("lifecycle") == "active", f"{service}: catalog must be active")
        require(catalog.get("riskClass") == risk_class, f"{service}: riskClass mismatch")
        require(bool(catalog.get("applyMode")), f"{service}: applyMode required")

    iam_policy = load(SERVICES / "iam-role-binding" / "v1" / "policy.json")
    for env in ("dev", "test", "prod"):
        allowed = set(iam_policy[env]["allowedValues"]["roleName"])
        require(allowed == APPROVED_IAM_ROLES, f"iam-role-binding/{env}: allowlist changed")
        require(not (allowed & FORBIDDEN_IAM_ROLES), f"iam-role-binding/{env}: privileged target role leaked")
        require(iam_policy[env]["allowedValues"]["principalType"] == ["ServicePrincipal"], f"iam-role-binding/{env}: principal type widened")

    vpn_schema = load(SERVICES / "vpn-gateway" / "v1" / "request.schema.json")
    require(not ({k.lower() for k in vpn_schema.get("properties", {})} & SECRET_KEYS), "VPN v1 must not accept secrets/PSK")

    iam = render(SERVICES / "iam-role-binding" / "v1" / "request.example.json")
    lb = render(SERVICES / "load-balancer" / "v1" / "request.example.json")
    vpn = render(SERVICES / "vpn-gateway" / "v1" / "request.example.json")
    assert iam and list(iam["assignments"].values())[0]["role_definition_name"] == "Reader"
    assert lb and lb["exposure"] == "public" and lb["subnet_id"] is None
    assert vpn and vpn["sku"] == "VpnGw1" and vpn["bgp_enabled"] is False and vpn["gateway_subnet_prefix"].endswith("/27")

    negative_variant("iam-role-binding", lambda r: r["spec"]["parameters"].update({"roleName": "Owner"}))
    negative_variant("iam-role-binding", lambda r: r["spec"]["parameters"].update({"scopeResourceId": "/subscriptions/c12c3a36-99d8-4741-bcef-cd7df5d5cd4a"}))
    negative_variant("vpn-gateway", lambda r: r["spec"]["parameters"].update({"sharedKey": "must-never-enter-git"}))
    negative_variant("load-balancer", lambda r: r["spec"]["parameters"].update({"exposure": "internal", "subnetResourceId": ""}))

    validate_runtime()
    print("IaC delivery contract valid: IAM + Standard Load Balancer + VPN Gateway foundation.")
    print("Standard network, Edge network and conditioned IAM Apply planes remain isolated.")
    print("VPN v1 has no PSK; billable Edge Apply requires explicit dispatch confirmation.")


if __name__ == "__main__":
    main()
