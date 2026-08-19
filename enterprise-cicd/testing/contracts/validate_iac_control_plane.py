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
    plan_workflow_path = REPO / ".github" / "workflows" / "iac-request-dev-plan.yml"
    apply_workflow_path = REPO / ".github" / "workflows" / "iac-request-dev-apply.yml"

    for path in (binding_path, bootstrap_path, plan_workflow_path, apply_workflow_path):
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
    require(plan["stateWriteAccess"] is False, "Plan identity must not receive state write access")
    require(apply["stateWriteAccess"] is True, "Apply identity must own remote-state writes")
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

    plan_workflow = plan_workflow_path.read_text(encoding="utf-8")
    require('environment: iac-dev-plan' in plan_workflow, "PR Plan must use iac-dev-plan Environment")
    require("ARM_USE_OIDC: 'true'" in plan_workflow, "PR Plan must use OIDC")
    require('STATE_WRITE="$(jq -r' in plan_workflow and 'test "$STATE_WRITE" = false' in plan_workflow, "PR Plan must enforce read-only state binding")
    require('-lock=false' in plan_workflow, "read-only PR Plan must not attempt a state lease/write")
    require('terraform -chdir="$STACK" apply' not in plan_workflow, "PR Plan workflow must never terraform apply")
    require('terraform destroy' not in plan_workflow, "PR Plan workflow must never terraform destroy")
    require("'delete' in x['actions']" in plan_workflow, "PR Plan must inspect destructive actions")

    apply_workflow = apply_workflow_path.read_text(encoding="utf-8")
    require('environment: iac-dev-apply' in apply_workflow, "Apply must use iac-dev-apply Environment")
    require("ARM_USE_OIDC: 'true'" in apply_workflow, "Apply must use OIDC")
    require('test "$STATE_WRITE" = true' in apply_workflow, "Apply must require state write binding")
    require('genericContributor' in apply_workflow and 'roleAssignmentWrite' in apply_workflow, "Apply binding privilege assertions missing")
    require('concurrency:' in apply_workflow and 'iac-dev-apply' in apply_workflow, "Apply must be serialized")
    require("service != 'managed-identity'" in apply_workflow, "DEV Apply v1 must fail closed for unsupported services")
    require("'delete' in x['actions']" in apply_workflow, "Apply must reject destructive plans")
    require('terraform destroy' not in apply_workflow, "automatic terraform destroy is forbidden")
    require('terraform -chdir="$STACK" apply' in apply_workflow, "Apply must execute the saved merge-time plan")
    require('/tmp/iac-apply/apply.tfplan' in apply_workflow, "Apply must use exact saved merge-time plan")
    require('managed-identity-verification.json' in apply_workflow, "post-apply Azure verification evidence missing")

    print("IaC control-plane security contract valid.")


if __name__ == "__main__":
    main()
