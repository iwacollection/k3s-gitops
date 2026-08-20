#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
ROOT = REPO / "enterprise-cicd"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> None:
    binding_path = ROOT / "contracts" / "iac-runtime-bindings.json"
    bootstrap_path = ROOT / "activation" / "iac" / "bootstrap-dev-iac-control-plane.sh"
    network_capability_path = ROOT / "activation" / "iac" / "activate-dev-network-capability.sh"
    plan_workflow_path = REPO / ".github" / "workflows" / "iac-request-dev-plan.yml"
    apply_workflow_path = REPO / ".github" / "workflows" / "iac-request-dev-apply.yml"
    drift_workflow_path = REPO / ".github" / "workflows" / "iac-dev-drift-detect.yml"

    for path in (
        binding_path,
        bootstrap_path,
        network_capability_path,
        plan_workflow_path,
        apply_workflow_path,
        drift_workflow_path,
    ):
        require(path.is_file(), f"missing IaC control-plane file: {path.relative_to(REPO)}")

    binding = load(binding_path)
    state = binding["state"]
    dev = binding["environments"]["dev"]
    plan = dev["plan"]
    apply = dev["apply"]

    require(state["authentication"] == "MicrosoftEntraID", "tfstate must use Microsoft Entra ID")
    require(state["sharedKeyAccess"] is False, "tfstate Shared Key access must remain disabled")
    require(plan["githubEnvironment"] == "iac-dev-plan", "DEV Plan GitHub Environment changed")
    require(apply["githubEnvironment"] == "iac-dev-apply", "DEV Apply GitHub Environment changed")
    require(plan["githubEnvironment"] != apply["githubEnvironment"], "Plan and Apply must use separate GitHub Environments")

    # The azurerm backend uses Azure Blob native state locking. A Lease Blob operation
    # requires blob write data permission, so even a plan-only identity needs container-
    # scoped Storage Blob Data Contributor. This does not grant Azure resource writes.
    require(plan["stateWriteAccess"] is True, "Plan identity must support azurerm backend state lease/write operations")
    require(plan["stateDataRole"] == "Storage Blob Data Contributor", "Plan backend data role must be Storage Blob Data Contributor")
    require(plan["stateScope"] == "container", "Plan state data permission must remain container-scoped")
    require(plan["resourceWriteAccess"] is False, "Plan identity must not receive Azure resource write access")

    require(apply["stateWriteAccess"] is True, "Apply identity must own remote-state writes")
    require(apply["stateDataRole"] == "Storage Blob Data Contributor", "Apply backend data role changed")
    require(apply["stateScope"] == "container", "Apply state data permission must remain container-scoped")
    require(apply["genericContributor"] is False, "Apply identity must not become generic Contributor")
    require(apply["roleAssignmentWrite"] is False, "Apply identity must not assign Azure RBAC roles")

    if dev["activationStatus"] == "ready":
        for phase in (plan, apply):
            for key in ("clientId", "principalId", "resourceId"):
                require(bool(phase.get(key)), f"ready binding requires {key} for {phase['identityName']}")
    else:
        require(dev["activationStatus"] == "pending-bootstrap", "unexpected DEV IaC activation status")

    bootstrap = bootstrap_path.read_text(encoding="utf-8")
    subprocess.run(["bash", "-n", str(bootstrap_path)], check=True)
    require('APPLY=0' in bootstrap, "bootstrap must default to PLAN ONLY")
    require('== "--apply"' in bootstrap and 'APPLY=1' in bootstrap, "bootstrap writes must require explicit --apply")
    require('PLAN_GITHUB_ENVIRONMENT="iac-dev-plan"' in bootstrap, "Plan FIC must bind iac-dev-plan")
    require('APPLY_GITHUB_ENVIRONMENT="iac-dev-apply"' in bootstrap, "Apply FIC must bind iac-dev-apply")
    require('CUSTOM_APPLY_ROLE_NAME="Enterprise IaC Managed Identity DEV Apply"' in bootstrap, "narrow Apply custom role missing")
    require('"Microsoft.Resources/subscriptions/resourceGroups/write"' in bootstrap, "Apply custom role must explicitly control resource-group writes")
    require('"Microsoft.ManagedIdentity/userAssignedIdentities/write"' in bootstrap, "Apply custom role must explicitly control UAMI writes")
    require('b24988ac-6180-42a0-ab88-20f7382dd24c' not in bootstrap, "generic Contributor role ID is forbidden in IaC bootstrap")
    require('8e3af657-a8ff-443c-a75c-2fe8c4bcb635' not in bootstrap, "Owner role ID is forbidden for runtime IaC identities")

    network_capability = network_capability_path.read_text(encoding="utf-8")
    subprocess.run(["bash", "-n", str(network_capability_path)], check=True)
    require('APPLY=0' in network_capability, "network capability activation must default to PLAN ONLY")
    require('ROLE_NAME="Enterprise IaC Network DEV Apply"' in network_capability, "narrow DEV network capability role missing")
    require('"Microsoft.Network/virtualNetworks/write"' in network_capability, "network capability must allow VNet writes")
    require('"Microsoft.Network/virtualNetworks/subnets/write"' in network_capability, "network capability must allow subnet writes")
    require('"Microsoft.Network/*"' not in network_capability, "broad Microsoft.Network wildcard is forbidden")
    require('4d97b98b-1d4f-4787-a291-c67834d212e7' in network_capability, "Network Contributor role ID guard is missing")
    for forbidden in (
        "publicIPAddresses/write",
        "natGateways/write",
        "virtualNetworkPeerings/write",
        "vpnGateways/write",
        "virtualNetworkGateways/write",
        "applicationGateways/write",
        "privateDnsZones/write",
    ):
        require(forbidden not in network_capability, f"paid/broad network write capability is forbidden: {forbidden}")

    plan_workflow = plan_workflow_path.read_text(encoding="utf-8")
    require('environment: iac-dev-plan' in plan_workflow, "PR Plan must use iac-dev-plan Environment")
    require("ARM_USE_OIDC: 'true'" in plan_workflow, "PR Plan must use OIDC")
    require('test "$STATE_WRITE" = true' in plan_workflow, "PR Plan must require backend lease/write capability")
    require("test \"$STATE_ROLE\" = 'Storage Blob Data Contributor'" in plan_workflow, "PR Plan must require container Blob Data Contributor")
    require('test "$STATE_SCOPE" = container' in plan_workflow, "PR Plan state scope must remain container")
    require('test "$RESOURCE_WRITE" = false' in plan_workflow, "PR Plan must deny Azure resource writes")
    require('-lock=false' not in plan_workflow, "PR Plan must use backend state locking")
    require('terraform -chdir="$STACK" apply' not in plan_workflow, "PR Plan workflow must never terraform apply")
    require('terraform destroy' not in plan_workflow, "PR Plan workflow must never terraform destroy")
    require("'delete' in x['actions']" in plan_workflow, "PR Plan must inspect destructive actions")
    require("'resourceMutationAllowed': False" in plan_workflow, "PR Plan evidence must state resource mutation is forbidden")
    require("'backendStateLeaseRequired': True" in plan_workflow, "PR Plan evidence must disclose backend lease requirement")

    apply_workflow = apply_workflow_path.read_text(encoding="utf-8")
    require('environment: iac-dev-apply' in apply_workflow, "Apply must use iac-dev-apply Environment")
    require("ARM_USE_OIDC: 'true'" in apply_workflow, "Apply must use OIDC")
    require("ARM_RESOURCE_PROVIDER_REGISTRATIONS: 'none'" in apply_workflow, "Apply must disable automatic provider registration with the supported AzureRM setting")
    require('test "$STATE_WRITE" = true' in apply_workflow, "Apply must require state write binding")
    require('genericContributor' in apply_workflow and 'roleAssignmentWrite' in apply_workflow, "Apply binding privilege assertions missing")
    require('concurrency:' in apply_workflow and 'iac-dev-apply' in apply_workflow, "Apply must be serialized")
    require("supported_services = {'managed-identity', 'network'}" in apply_workflow, "DEV Apply service capability allowlist changed")
    require("'delete' in x['actions']" in apply_workflow, "Apply must reject destructive plans")
    require('terraform destroy' not in apply_workflow, "automatic terraform destroy is forbidden")
    require('terraform -chdir="$STACK" apply' in apply_workflow, "Apply must execute the saved merge-time plan")
    require('/tmp/iac-apply/apply.tfplan' in apply_workflow, "Apply must use exact saved merge-time plan")
    require('managed-identity-verification.json' in apply_workflow, "managed identity post-apply evidence missing")
    require('network-verification.json' in apply_workflow and 'subnet-verification.json' in apply_workflow, "network post-apply Azure evidence missing")
    require("'paidNetworkAddOnsDetected': False" in apply_workflow, "network verification must assert paid add-ons are absent")

    drift_workflow = drift_workflow_path.read_text(encoding="utf-8")
    require('workflow_dispatch:' in drift_workflow, "Drift detection must support explicit execution")
    require('schedule:' in drift_workflow, "Drift detection must be scheduled")
    require('environment: iac-dev-plan' in drift_workflow, "Drift detection must reuse the read-only DEV resource-plane identity")
    require("ARM_USE_OIDC: 'true'" in drift_workflow, "Drift detection must use OIDC")
    require('-detailed-exitcode' in drift_workflow, "Drift detection must distinguish convergence from pending changes")
    require('-lock=true' in drift_workflow, "Drift detection must respect Terraform state locking")
    require("'resourceMutationAllowed': False" in drift_workflow, "Drift evidence must state that Azure resource mutation is forbidden")
    require("'automaticRemediation': False" in drift_workflow, "Drift detection must not silently auto-remediate")
    require('terraform -chdir="$STACK" apply' not in drift_workflow, "Drift detection must never terraform apply")
    require('terraform destroy' not in drift_workflow, "Drift detection must never terraform destroy")
    require('environment: iac-dev-apply' not in drift_workflow, "Drift detection must never use the Apply Environment")

    print("IaC control-plane security contract valid.")


if __name__ == "__main__":
    main()
