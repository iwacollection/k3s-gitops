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
    dev_plan_path = REPO / ".github" / "workflows" / "iac-decommission-dev-plan.yml"
    dev_apply_path = REPO / ".github" / "workflows" / "iac-decommission-dev-apply.yml"
    protected_plan_path = REPO / ".github" / "workflows" / "iac-decommission-protected-plan.yml"
    protected_apply_path = REPO / ".github" / "workflows" / "iac-decommission-protected-apply.yml"
    drift_path = REPO / ".github" / "workflows" / "iac-dev-drift-detect.yml"

    for path in (
        validator_path, readme_path, guard_path, dev_plan_path, dev_apply_path,
        protected_plan_path, protected_apply_path, drift_path,
    ):
        require(path.is_file(), f"missing governed decommission file: {path.relative_to(REPO)}")

    validator = validator_path.read_text(encoding="utf-8")
    for token in (
        'SUPPORTED_ENVIRONMENTS = {"dev", "test", "prod"}',
        '"managed-identity"', '"network"', '"iam-role-binding"', '"load-balancer"', '"vpn-gateway"',
        'kind") != "DecommissionRequest"',
        'metadata.changeTicket must look like CHG-1234',
        "DESTROY {spec['requestName']}",
        'retired InfrastructureRequest must remain in Git',
        'exactly one immutable tombstone is allowed',
        'environment_decommission_root = DECOMMISSION_ROOT / environment',
        'environment_request_root = REQUEST_ROOT / environment',
    ):
        require(token in validator, f"generalized decommission validator contract missing: {token}")

    guard = guard_path.read_text(encoding="utf-8")
    require("status != 'A'" in guard, "DEV tombstones must remain add-only")
    require('tombstones are append-only and immutable' in guard, "DEV tombstone immutability guard missing")
    require('InfrastructureRequest deletion is forbidden' in guard, "source request deletion guard missing")
    require('retired InfrastructureRequest is immutable' in guard, "retired source request mutation guard missing")

    dev_plan = dev_plan_path.read_text(encoding="utf-8")
    require('environment: iac-dev-plan' in dev_plan, "DEV decommission Plan must use iac-dev-plan")
    require("ARM_USE_OIDC: 'true'" in dev_plan, "DEV decommission Plan must use OIDC")
    require('-destroy' in dev_plan and '-lock=true' in dev_plan, "DEV destroy Plan/state lock missing")
    require("x['actions'] != ['delete']" in dev_plan, "DEV decommission must remain delete-only")
    require('terraform -chdir="$STACK" apply' not in dev_plan, "DEV PR destroy Plan must never Apply")

    dev_apply = dev_apply_path.read_text(encoding="utf-8")
    require('environment: iac-dev-apply' in dev_apply, "DEV standard decommission Apply environment changed")
    require('-destroy' in dev_apply and '-lock=true' in dev_apply, "DEV merge-time destroy re-plan/state lock missing")
    require('/tmp/iac-decommission-apply/destroy.tfplan' in dev_apply, "DEV exact saved destroy plan missing")
    require('terraform destroy' not in dev_apply, "direct terraform destroy remains forbidden")
    require('retention-days: 365' in dev_apply, "DEV decommission evidence retention changed")

    protected_plan = protected_plan_path.read_text(encoding="utf-8")
    for token in (
        "'iam-role-binding','load-balancer','vpn-gateway'",
        'environment: iac-${{ matrix.item.environment }}-plan',
        "ARM_USE_OIDC: 'true'", '-destroy', '-lock=true', '-lock-timeout=5m',
        "r.get('type') != 'azurerm_role_assignment'",
        'foreign Azure resources block decommission',
        "x['actions'] != ['delete']",
        "'automaticApply':False",
        'retention-days: 365',
    ):
        require(token in protected_plan, f"protected decommission Plan contract missing: {token}")
    require('terraform -chdir="$STACK" apply' not in protected_plan, "protected PR Plan must never Apply")

    protected_apply = protected_apply_path.read_text(encoding="utf-8")
    for token in (
        'workflow_dispatch:', 'confirm_destroy:',
        "service in {'load-balancer','vpn-gateway'}",
        "service == 'iam-role-binding'",
        'environment: ${{ needs.resolve.outputs.github_environment }}',
        "ARM_USE_OIDC: 'true'", 'id-token: write',
        '-destroy', '-lock=true', '-lock-timeout=5m',
        "x['actions'] != ['delete']",
        '/tmp/iac-protected-decommission-apply/destroy.tfplan',
        'terraform -chdir="$STACK" apply',
        'Terraform state is not empty after protected decommission',
        'role assignments still exist after decommission',
        'resource group still exists after decommission',
        'retention-days: 365',
    ):
        require(token in protected_apply, f"protected decommission Apply contract missing: {token}")
    require('terraform destroy' not in protected_apply, "direct terraform destroy is forbidden in protected runtime")

    drift = drift_path.read_text(encoding="utf-8")
    require("Path('enterprise-cicd/iac-decommission/dev')" in drift, "DEV drift must honor tombstones")
    require('if str(path) in retired:' in drift, "DEV drift must exclude retired requests")

    readme = readme_path.read_text(encoding="utf-8")
    require('Tombstone PR' in readme and 'foreign resources block deletion' in readme, "decommission operator contract is incomplete")

    print("IaC governed decommission contract valid: DEV standard + protected multi-environment lifecycle.")


if __name__ == "__main__":
    main()
