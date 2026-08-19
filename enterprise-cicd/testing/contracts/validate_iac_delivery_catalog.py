#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
CATALOG = REPO / "enterprise-cicd" / "iac-catalog"
RENDERER = CATALOG / "render_request.py"
SERVICES = CATALOG / "services"

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


def main() -> None:
    for service, risk_class in NEW_SERVICES.items():
        root = SERVICES / service / "v1"
        for name in ("catalog.json", "defaults.json", "policy.json", "request.schema.json", "request.example.json", "README.md"):
            if not (root / name).is_file():
                fail(f"{service}: missing {name}")
        catalog = load(root / "catalog.json")
        if catalog.get("lifecycle") != "active":
            fail(f"{service}: catalog must be active")
        if catalog.get("riskClass") != risk_class:
            fail(f"{service}: unexpected riskClass")
        if not catalog.get("applyMode"):
            fail(f"{service}: applyMode is required")

    iam_policy = load(SERVICES / "iam-role-binding" / "v1" / "policy.json")
    for env in ("dev", "test", "prod"):
        allowed = set(iam_policy[env]["allowedValues"]["roleName"])
        if allowed != APPROVED_IAM_ROLES:
            fail(f"iam-role-binding/{env}: allowed roles changed: {sorted(allowed)}")
        if allowed & FORBIDDEN_IAM_ROLES:
            fail(f"iam-role-binding/{env}: privileged role leaked into self-service policy")
        if iam_policy[env]["allowedValues"]["principalType"] != ["ServicePrincipal"]:
            fail(f"iam-role-binding/{env}: v1 must remain ServicePrincipal-only")

    vpn_schema = load(SERVICES / "vpn-gateway" / "v1" / "request.schema.json")
    vpn_keys = {key.lower() for key in vpn_schema.get("properties", {})}
    if vpn_keys & SECRET_KEYS:
        fail("vpn-gateway/v1 must not accept PSK/shared key/password inputs")

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

    print("IaC delivery catalog contract valid: IAM + Load Balancer + VPN Gateway.")
    print("IAM self-service roles are low-risk allowlisted; subscription-root RBAC is rejected.")
    print("VPN v1 contains no PSK/shared-key input; billable Edge capabilities remain protected.")


if __name__ == "__main__":
    main()
