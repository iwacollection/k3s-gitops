#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
ROOT = REPO / "enterprise-cicd"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def main() -> None:
    validator_path = ROOT / "iac-decommission" / "validate_decommission.py"
    readme_path = ROOT / "iac-decommission" / "README.md"
    guard_path = REPO / ".github" / "workflows" / "iac-dev-retirement-guard.yml"
    plan_path = REPO / ".github" / "workflows" / "iac-decommission-dev-plan.yml"
    apply_path = REPO / ".github" / "workflows" / "iac-decommission-dev-apply.yml"
    drift_path = REPO / ".github" / "workflows" / "iac-dev-drift-detect.yml"

    for path in (validator_path, readme_path, guard_path, plan_path, apply_path, drift_path):
        require(path.is_file(), f"missing governed decommission file: {path.relative_to(REPO)}")

    validator = validator_path.read_text(encoding="utf-8")
    require('SUPPORTED_SERVICES = {"managed-identity", "network"}' in validator, "DEV decommission capability allowlist changed")
    require('kind") != "DecommissionRequest"' in validator, "DecommissionRequest kind validation missing")
    require('metadata.changeTicket must look like CHG-1234' in validator, "change ticket validation missing")
    require('DESTROY {spec[\'requestName\']}' in validator, "typed DESTROY confirmation validation missing")
    require('retired InfrastructureRequest must remain in Git' in validator, "source request audit retention guard missing")
    require('exactly one immutable tombstone is allowed' in validator, "duplicate tombstone guard missing")

    guard = guard_path.read_text(encoding="utf-8")
    require("status != 'A'" in guard, "tombstones must be add-only")
    require('tombstones are append-only and immutable' in guard, "tombstone immutability guard missing")
    require('InfrastructureRequest deletion is forbidden' in guard, "source request deletion guard missing")
    require('retired InfrastructureRequest is immutable' in guard, "retired source request mutation guard missing")
    require('validate_decommission.py' in guard, "retirement guard must validate new tombstones")

    plan = plan_path.read_text(encoding="utf-8")
    require('environment: iac-dev-plan' in plan, "decommission PR Plan must use iac-dev-plan")
    require("ARM_USE_OIDC: 'true'" in plan, "decommission PR Plan must use OIDC")
    require('-destroy' in plan, "decommission PR must produce a Terraform destroy plan")
    require('-lock=true' in plan and '-lock-timeout=5m' in plan, "decommission PR Plan must use remote state locking")
    require('foreign Azure resources block resource-group decommission' in plan, "foreign resource ownership guard missing from decommission Plan")
    require("x['actions'] != ['delete']" in plan, "decommission Plan must require delete-only actions")
    require("'resourceMutationAllowed': False" in plan, "decommission PR evidence must deny mutation")
    require("'automaticApply': False" in plan, "decommission PR must not auto-apply")
    require('terraform -chdir="$STACK" apply' not in plan, "decommission PR Plan must never apply")
    require('terraform destroy' not in plan, "direct terraform destroy is forbidden")

    apply = apply_path.read_text(encoding="utf-8")
    require('environment: iac-dev-apply' in apply, "decommission Apply must use iac-dev-apply")
    require("ARM_USE_OIDC: 'true'" in apply, "decommission Apply must use OIDC")
    require('group: iac-dev-apply' in apply, "decommission must serialize with normal DEV Apply")
    require('-destroy' in apply, "decommission Apply must re-plan destroy at merge time")
    require('-lock=true' in apply and '-lock-timeout=5m' in apply, "decommission Apply must lock remote state")
    require('foreign Azure resources block decommission Apply' in apply, "merge-time foreign resource guard missing")
    require("x['actions'] != ['delete']" in apply, "decommission Apply must remain delete-only")
    require('/tmp/iac-decommission-apply/destroy.tfplan' in apply, "decommission Apply must use exact saved destroy plan")
    require('terraform -chdir="$STACK" apply' in apply, "saved destroy plan Apply is missing")
    require('terraform destroy' not in apply, "direct terraform destroy is forbidden")
    require('state list' in apply and 'Terraform state is not empty' in apply, "post-decommission state-empty verification missing")
    require('az group exists' in apply and 'resource group still exists after decommission' in apply, "post-decommission Azure absence verification missing")
    require('retention-days: 365' in apply, "decommission audit evidence must be retained for 365 days")

    drift = drift_path.read_text(encoding="utf-8")
    require("Path('enterprise-cicd/iac-decommission/dev')" in drift, "drift discovery must read retirement tombstones")
    require('if str(path) in retired:' in drift, "drift must exclude retired InfrastructureRequests")
    require("'enterprise-cicd/iac-decommission/dev/**.json'" in drift, "tombstone merge must refresh drift scope")

    readme = readme_path.read_text(encoding="utf-8")
    require('Tombstone PR' in readme and 'foreign resources block deletion' in readme, "decommission operator contract is incomplete")

    print("IaC governed decommission security contract valid.")


if __name__ == "__main__":
    main()
