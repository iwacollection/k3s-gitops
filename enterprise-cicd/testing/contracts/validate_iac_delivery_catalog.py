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
SERVICES = CATALOG / "services"
RENDERER = CATALOG / "render_request.py"
ACTIVATION = ROOT / "activation" / "iac"
BINDINGS = ROOT / "contracts" / "iac-runtime-bindings.json"
WORKFLOWS = REPO / ".github" / "workflows"

EDGE_SERVICES = {"load-balancer", "vpn-gateway"}
WORKLOAD_SERVICES = {"acr", "storage", "key-vault", "service-bus", "managed-redis", "postgresql-flexible"}
APPROVED_IAM_ROLES = {"Reader", "AcrPull", "Storage Blob Data Reader", "Key Vault Secrets User"}
SECRET_KEYS = {"sharedkey", "sharedsecret", "psk", "password", "secret"}


def require(ok: bool, message: str) -> None:
    if not ok:
        raise SystemExit(message)


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def render(request: Path, expect_success: bool = True) -> dict | None:
    with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as out:
        output = Path(out.name)
    proc = subprocess.run(
        [sys.executable, str(RENDERER), "--request", str(request), "--output", str(output)],
        cwd=REPO, text=True, capture_output=True,
    )
    try:
        if expect_success:
            require(proc.returncode == 0, f"renderer failed for {request}: {proc.stderr or proc.stdout}")
            return load(output)
        require(proc.returncode != 0, f"renderer accepted forbidden request {request}")
        return None
    finally:
        output.unlink(missing_ok=True)


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


def role_actions(script: Path) -> set[str]:
    text = script.read_text(encoding="utf-8")
    start = text.index('ROLE_BODY="$(cat <<EOF')
    end = text.index('\nEOF\n)"', start)
    body = text[start:end]
    return set(re.findall(r'"(Microsoft\.[^"]+)"', body))


def main() -> None:
    # All delivery activation scripts must be syntactically valid and plan-only by default.
    edge_script = ACTIVATION / "activate-iac-edge-network-capability.sh"
    iam_script = ACTIVATION / "activate-iac-iam-capability.sh"
    workload_script = ACTIVATION / "activate-iac-workload-services-capability.sh"
    delivery_script = ACTIVATION / "activate-iac-delivery-capabilities.sh"
    for script in (edge_script, iam_script, workload_script, delivery_script):
        require(script.is_file(), f"missing activation script {script.relative_to(REPO)}")
        subprocess.run(["bash", "-n", str(script)], check=True)
        value = script.read_text(encoding="utf-8")
        require("--apply" in value, f"{script.name}: explicit Apply switch required")
    require("WORKLOAD_SCRIPT=" in delivery_script.read_text(encoding="utf-8"), "unified activation missing workload plane")

    edge_actions = role_actions(edge_script)
    for required in {
        "Microsoft.Network/publicIPAddresses/write",
        "Microsoft.Network/loadBalancers/write",
        "Microsoft.Network/loadBalancers/backendAddressPools/write",
        "Microsoft.Network/virtualNetworkGateways/write",
    }:
        require(required in edge_actions, f"Edge role missing {required}")
    for forbidden in {
        "Microsoft.Network/*",
        "Microsoft.Network/loadBalancers/probes/write",
        "Microsoft.Network/loadBalancers/probes/delete",
        "Microsoft.Network/loadBalancers/loadBalancingRules/write",
        "Microsoft.Network/loadBalancers/loadBalancingRules/delete",
        "Microsoft.Authorization/roleAssignments/write",
    }:
        require(forbidden not in edge_actions, f"Edge role contains forbidden/unsupported action {forbidden}")
    require(not any("virtualNetworkPeerings" in x or "natGateways" in x or "applicationGateways" in x or "virtualNetworkGatewayConnections" in x for x in edge_actions), "Edge role widened beyond LB/VPN foundation")

    iam = iam_script.read_text(encoding="utf-8")
    require('RBAC_ADMIN_ROLE_ID="f58310d9-a9f6-439a-9e8d-f62e7b41a168"' in iam, "IAM conditioned RBAC Administrator missing")
    condition_line = next(line for line in iam.splitlines() if line.startswith("CONDITION="))
    for token in ("roleAssignments/write", "roleAssignments/delete", "RoleDefinitionId", "PrincipalType", "ServicePrincipal"):
        require(token in condition_line, f"IAM ABAC condition missing {token}")

    workload_actions = role_actions(workload_script)
    for required in {
        "Microsoft.ContainerRegistry/registries/write",
        "Microsoft.Storage/storageAccounts/write",
        "Microsoft.KeyVault/vaults/write",
        "Microsoft.ServiceBus/namespaces/write",
        "Microsoft.Cache/redisEnterprise/write",
        "Microsoft.DBforPostgreSQL/flexibleServers/write",
        "Microsoft.Network/privateEndpoints/write",
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Insights/diagnosticSettings/write",
    }:
        require(required in workload_actions, f"Workload role missing {required}")
    for forbidden in {
        "Microsoft.Authorization/roleAssignments/write",
        "Microsoft.Network/*",
        "Microsoft.Storage/storageAccounts/listkeys/action",
        "Microsoft.ContainerRegistry/registries/listCredentials/action",
        "Microsoft.ServiceBus/namespaces/authorizationRules/listkeys/action",
    }:
        require(forbidden not in workload_actions, f"Workload role contains sensitive permission {forbidden}")

    # Catalog routing contract.
    iam_catalog = load(SERVICES / "iam-role-binding" / "v1" / "catalog.json")
    require(iam_catalog.get("applyMode") == "dedicated-iam-oidc", "IAM applyMode changed")
    for service in EDGE_SERVICES:
        catalog = load(SERVICES / service / "v1" / "catalog.json")
        require(catalog.get("lifecycle") == "active" and catalog.get("applyMode") == "protected-edge-oidc", f"{service}: Edge Apply contract invalid")
        require(catalog.get("billingImpact") == "billable", f"{service}: billing guard required")
    for service in WORKLOAD_SERVICES:
        catalog = load(SERVICES / service / "v1" / "catalog.json")
        require(catalog.get("lifecycle") == "active", f"{service}: workload Catalog must be active")
        require(catalog.get("applyMode") == "protected-workload-oidc", f"{service}: workload Apply route missing")
        require(catalog.get("billingImpact") == "billable", f"{service}: billing guard required")

    iam_policy = load(SERVICES / "iam-role-binding" / "v1" / "policy.json")
    for env in ("dev", "test", "prod"):
        require(set(iam_policy[env]["allowedValues"]["roleName"]) == APPROVED_IAM_ROLES, f"IAM role allowlist changed in {env}")
        require(iam_policy[env]["allowedValues"]["principalType"] == ["ServicePrincipal"], f"IAM principal type widened in {env}")

    vpn_schema = load(SERVICES / "vpn-gateway" / "v1" / "request.schema.json")
    require(not ({k.lower() for k in vpn_schema.get("properties", {})} & SECRET_KEYS), "VPN v1 must not accept PSK/secrets")

    # Positive renderer contracts.
    iam_vars = render(SERVICES / "iam-role-binding" / "v1" / "request.example.json")
    lb_vars = render(SERVICES / "load-balancer" / "v1" / "request.example.json")
    vpn_vars = render(SERVICES / "vpn-gateway" / "v1" / "request.example.json")
    require(iam_vars is not None and next(iter(iam_vars["assignments"].values()))["role_definition_name"] == "Reader", "IAM renderer contract failed")
    require(lb_vars is not None and lb_vars["exposure"] == "public", "LB renderer contract failed")
    require(vpn_vars is not None and vpn_vars["sku"] == "VpnGw1" and vpn_vars["bgp_enabled"] is False, "VPN renderer contract failed")
    for service in WORKLOAD_SERVICES:
        rendered = render(SERVICES / service / "v1" / "request.example.json")
        require(rendered is not None, f"{service}: renderer contract failed")

    negative_variant("iam-role-binding", lambda r: r["spec"]["parameters"].update({"roleName": "Owner"}))
    negative_variant("iam-role-binding", lambda r: r["spec"]["parameters"].update({"scopeResourceId": "/subscriptions/c12c3a36-99d8-4741-bcef-cd7df5d5cd4a"}))
    negative_variant("vpn-gateway", lambda r: r["spec"]["parameters"].update({"sharedKey": "must-never-enter-git"}))

    binding = load(BINDINGS)
    require(binding.get("version") == 3, "runtime binding schema must be v3")
    require(binding["state"]["authentication"] == "MicrosoftEntraID" and binding["state"]["sharedKeyAccess"] is False, "state must remain Entra-only")
    for env in ("dev", "test", "prod"):
        runtime = binding["environments"][env]
        for plane in ("edge", "iam", "workload"):
            require(plane in runtime, f"{env}: missing {plane} Apply plane")
        require(runtime["edge"]["githubEnvironment"] == f"iac-{env}-edge-apply", f"{env}: Edge Environment mismatch")
        require(runtime["iam"]["githubEnvironment"] == f"iac-{env}-iam-apply", f"{env}: IAM Environment mismatch")
        require(runtime["workload"]["githubEnvironment"] == f"iac-{env}-workload-apply", f"{env}: Workload Environment mismatch")
        require(set(runtime["workload"]["supportedServices"]) == WORKLOAD_SERVICES, f"{env}: Workload service coverage mismatch")

    for workflow, tokens in {
        "iac-request-protected-capability-apply.yml": ("load-balancer", "vpn-gateway", "iam-role-binding", "apply.tfplan"),
        "iac-request-workload-capability-apply.yml": ("protected-workload-oidc", "Post-Apply Terraform Plan still contains changes", "apply.tfplan"),
        "iac-request-apply.yml": ("standard-oidc", "protected-edge-oidc", "dedicated-iam-oidc", "protected-workload-oidc", "Require post-Apply Terraform convergence"),
    }.items():
        value = (WORKFLOWS / workflow).read_text(encoding="utf-8")
        for token in tokens:
            require(token in value, f"{workflow}: missing {token}")

    subprocess.run([sys.executable, str(REPO / "enterprise-cicd/testing/contracts/validate_iac_apply_coverage.py")], cwd=REPO, check=True)
    print("IaC delivery contract valid: all active Catalogs have isolated Apply routing.")
    print("Apply invariant: exact saved plan + state lock + no delete + post-Apply No Changes.")


if __name__ == "__main__":
    main()
