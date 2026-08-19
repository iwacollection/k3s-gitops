#!/usr/bin/env python3
from __future__ import annotations

import json
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
WORKFLOW = REPO / ".github" / "workflows" / "iac-request-protected-capability-apply.yml"
BINDINGS = ROOT / "contracts" / "iac-runtime-bindings.json"

NEW_SERVICES = {
    "iam-role-binding": "privileged",
    "load-balancer": "network-edge",
    "vpn-gateway": "network-edge",
}
APPROVED_IAM_ROLES = {
    "Reader",
    "AcrPull",
    "Storage Blob Data Reader",
    "Key Vault Secrets User",
}
APPROVED_IAM_ROLE_IDS = {
    "acdd72a7-3385-48ef-bd42-f606fba81ae7",
    "7f951dda-4ed3-4680-a7ca-43fe172d538d",
    "2a2b9908-6ea1-4ae2-8e65-a410df84e7d1",
    "4633458b-17de-408a-b874-0445c86b69e6",
}
FORBIDDEN_IAM_ROLES = {
    "Owner",
    "Contributor",
    "User Access Administrator",
    "Role Based Access Control Administrator",
    "Network Contributor",
}
SECRET_KEYS = {"sharedkey", "sharedsecret", "psk", "password", "secret"}


def fail(message: str) -> None:
    raise SystemExit(message)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def render(request: Path, expect_success: bool = True) -> tuple[int, str, dict | None]:
    with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as out:
        output = Path(out.name)
    proc = subprocess.run(
        [sys.executable, str(RENDERER), "--request", str(request), "--output", str(output)],
        cwd=REPO,
        text=True,
        capture_output=True,
    )
    if expect_success and proc.returncode != 0:
        fail(f"renderer failed for {request}: {proc.stderr or proc.stdout}")
    if not expect_success and proc.returncode == 0:
        fail(f"renderer unexpectedly accepted forbidden request {request}")
    data = load(output) if proc.returncode == 0 else None
    output.unlink(missing_ok=True)
    return proc.returncode, proc.stderr + proc.stdout, data


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


def validate_activation_runtime() -> None:
    edge_path = ACTIVATION / "activate-iac-edge-network-capability.sh"
    iam_path = ACTIVATION / "activate-iac-iam-capability.sh"
    for path in (edge_path, iam_path, WORKFLOW, BINDINGS):
        require(path.is_file(), f"missing protected IaC runtime file: {path.relative_to(REPO)}")
    subprocess.run(["bash", "-n", str(edge_path)], check=True)
    subprocess.run(["bash", "-n", str(iam_path)], check=True)

    edge = edge_path.read_text(encoding="utf-8")
    require('APPLY=0' in edge and '--apply' in edge, "Edge activation must default to PLAN ONLY")
    require('k3s-gitops-iac-edge-apply-${ENVIRONMENT}-uami' in edge, "Edge runtime must use a dedicated UAMI")
    for required in (
        'Microsoft.Network/publicIPAddresses/write',
        'Microsoft.Network/loadBalancers/write',
        'Microsoft.Network/loadBalancers/backendAddressPools/write',
        'Microsoft.Network/loadBalancers/probes/write',
        'Microsoft.Network/loadBalancers/loadBalancingRules/write',
        'Microsoft.Network/virtualNetworkGateways/write',
    ):
        require(required in edge, f"Edge custom role missing {required}")
    for forbidden in (
        '"Microsoft.Network/*"',
        'virtualNetworkPeerings/write',
        'natGateways/write',
        'applicationGateways/write',
        'virtualNetworkGatewayConnections/write',
        'Microsoft.Authorization/roleAssignments/write',
    ):
        require(forbidden not in edge, f"Edge capability leaked forbidden permission: {forbidden}")

    iam = iam_path.read_text(encoding="utf-8")
    require('APPLY=0' in iam and '--apply' in iam, "IAM activation must default to PLAN ONLY")
    require('k3s-gitops-iac-iam-apply-${ENVIRONMENT}-uami' in iam, "IAM runtime must use a dedicated UAMI")
    require('f58310d9-a9f6-439a-9e8d-f62e7b41a168' in iam, "conditioned RBAC Administrator role is required")
    require("conditionVersion': '2.0'" in iam or '"conditionVersion": "2.0"' in iam, "IAM delegation must use ABAC condition version 2.0")
    require('RoleDefinitionId' in iam and 'PrincipalType' in iam and 'ServicePrincipal' in iam, "IAM ABAC condition must constrain role and principal type")
    for role_id in APPROVED_IAM_ROLE_IDS:
        require(role_id in iam, f"IAM conditioned allowlist missing role {role_id}")
    for forbidden_id in (
        '8e3af657-a8ff-443c-a75c-2fe8c4bcb635',
        'b24988ac-6180-42a0-ab88-20f7382dd24c',
        '18d7d88d-d35e-4fb5-a5c3-7773c20a72d9',
    ):
        require(forbidden_id not in iam.split('CONDITION=')[1].split('\n\n')[0], f"privileged role leaked into IAM ABAC target allowlist: {forbidden_id}")

    binding = load(BINDINGS)
    require(binding['version'] == 2, "IaC runtime binding schema must be v2")
    require(binding['state']['authentication'] == 'MicrosoftEntraID', "state must remain Entra-only")
    require(binding['state']['sharedKeyAccess'] is False, "state Shared Key must remain disabled")
    for env in ('dev', 'test', 'prod'):
        current = binding['environments'][env]
        require('edge' in current and 'iam' in current, f"{env}: isolated edge/iam bindings are required")
        require(current['edge']['githubEnvironment'] == f'iac-{env}-edge-apply', f"{env}: Edge Environment mismatch")
        require(current['iam']['githubEnvironment'] == f'iac-{env}-iam-apply', f"{env}: IAM Environment mismatch")

    workflow = WORKFLOW.read_text(encoding="utf-8")
    require('workflow_dispatch:' in workflow, "billable/privileged capability Apply must require explicit dispatch")
    require('confirm_billable:' in workflow, "Edge Apply requires explicit billing acknowledgement")
    require("service in {'load-balancer', 'vpn-gateway'}" in workflow, "Edge service allowlist missing")
    require("service == 'iam-role-binding'" in workflow, "IAM service allowlist missing")
    require('environment: ${{ needs.resolve.outputs.github_environment }}' in workflow, "capability Apply must use bound GitHub Environment")
    require('ARM_USE_OIDC:' in workflow and 'id-token: write' in workflow, "capability Apply must use OIDC")
    require('-lock=true' in workflow, "capability Apply must use native state locking")
    require("'delete' in item['actions']" in workflow, "capability Apply must reject delete actions")
    require('/tmp/iac-protected-apply/apply.tfplan' in workflow, "capability Apply must execute exact saved plan")
    require('vpn-connection list' in workflow and "siteConnections':0" in workflow, "VPN v1 must verify that no S2S connection/PSK resource is created")


def main() -> None:
    for service, risk_class in NEW_SERVICES.items():
        root = SERVICES / service / "v1"
        for name in ("catalog.json", "defaults.json", "policy.json", "request.schema.json", "request.example.json", "README.md"):
            require((root / name).is_file(), f"{service}: missing {name}")
        catalog = load(root / "catalog.json")
        require(catalog.get("lifecycle") == "active", f"{service}: catalog must be active")
        require(catalog.get("riskClass") == risk_class, f"{service}: unexpected riskClass")
        require(bool(catalog.get("applyMode")), f"{service}: applyMode is required")

    iam_policy = load(SERVICES / "iam-role-binding" / "v1" / "policy.json")
    for env in ("dev", "test", "prod"):
        allowed = set(iam_policy[env]["allowedValues"]["roleName"])
        require(allowed == APPROVED_IAM_ROLES, f"iam-role-binding/{env}: allowed roles changed: {sorted(allowed)}")
        require(not (allowed & FORBIDDEN_IAM_ROLES), f"iam-role-binding/{env}: privileged role leaked into self-service policy")
        require(iam_policy[env]["allowedValues"]["principalType"] == ["ServicePrincipal"], f"iam-role-binding/{env}: v1 must remain ServicePrincipal-only")

    vpn_schema = load(SERVICES / "vpn-gateway" / "v1" / "request.schema.json")
    vpn_keys = {key.lower() for key in vpn_schema.get("properties", {})}
    require(not (vpn_keys & SECRET_KEYS), "vpn-gateway/v1 must not accept PSK/shared key/password inputs")

    iam = render(SERVICES / "iam-role-binding" / "v1" / "request.example.json")[2]
    lb = render(SERVICES / "load-balancer" / "v1" / "request.example.json")[2]
    vpn = render(SERVICES / "vpn-gateway" / "v1" / "request.example.json")[2]

    assert iam is not None and list(iam["assignments"].values())[0]["role_definition_name"] == "Reader"
    assert lb is not None and lb["exposure"] == "public" and lb["subnet_id"] is None
    assert lb["protocol"] == "Tcp" and lb["probe_protocol"] == "Tcp"
    assert vpn is not None and vpn["sku"] == "VpnGw1" and vpn["bgp_enabled"] is False
    assert vpn["gateway_subnet_prefix"].endswith("/27")

    negative_variant("iam-role-binding", lambda req: req["spec"]["parameters"].update({"roleName": "Owner"}))
    negative_variant("iam-role-binding", lambda req: req["spec"]["parameters"].update({"scopeResourceId": "/subscriptions/c12c3a36-99d8-4741-bcef-cd7df5d5cd4a"}))
    negative_variant("vpn-gateway", lambda req: req["spec"]["parameters"].update({"sharedKey": "must-never-enter-git"}))
    negative_variant("load-balancer", lambda req: req["spec"]["parameters"].update({"exposure": "internal", "subnetResourceId": ""}))

    validate_activation_runtime()

    print("IaC delivery contract valid: IAM + Standard Load Balancer + VPN Gateway foundation.")
    print("IAM uses conditioned RBAC delegation; Edge uses an isolated narrow network role.")
    print("VPN v1 contains no PSK/shared-key input; billable Edge Apply requires explicit dispatch confirmation.")


if __name__ == "__main__":
    main()
