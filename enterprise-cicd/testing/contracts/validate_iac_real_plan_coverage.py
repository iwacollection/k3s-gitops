#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
SERVICES = REPO / "enterprise-cicd" / "iac-catalog" / "services"
WORKFLOW = REPO / ".github" / "workflows" / "iac-active-catalog-real-plan.yml"
DELIVERY = REPO / ".github" / "workflows" / "iac-delivery-catalog-validate.yml"
EXPECTED = {
    "managed-identity", "network", "iam-role-binding", "load-balancer", "vpn-gateway",
    "acr", "storage", "key-vault", "service-bus", "managed-redis", "postgresql-flexible",
}


def require(ok: bool, message: str) -> None:
    if not ok:
        raise SystemExit(message)


def main() -> None:
    active=set()
    for directory in SERVICES.iterdir():
        path=directory / 'v1' / 'catalog.json'
        if directory.is_dir() and path.is_file():
            catalog=json.loads(path.read_text())
            if catalog.get('lifecycle') == 'active': active.add(directory.name)
    require(active == EXPECTED, f'active Catalog set changed: {sorted(active)}')

    require(WORKFLOW.is_file(), 'all-active-Catalog real Plan workflow missing')
    workflow=WORKFLOW.read_text()
    for service in EXPECTED:
        require(f'- {service}' in workflow, f'all-active real Plan matrix missing {service}')
        require(f"'{service}'" in workflow, f'all-active Plan resource boundary missing {service}')
    for token in (
        'platform foundation must be applied before full Catalog Plan',
        'environment: ${{ needs.binding.outputs.github_environment }}',
        "ARM_USE_OIDC: 'true'", "ARM_USE_AZUREAD: 'true'",
        '--scope catalog', '-lock=true', '-lock-timeout=5m',
        'realRemoteStatePlan', "'delete' in x['actions']",
        'unexpectedResourceTypes', 'ALL_ACTIVE_CATALOG_REAL_PLAN=PASSED',
    ):
        require(token in workflow, f'all-active real Plan workflow missing {token!r}')

    delivery=DELIVERY.read_text()
    for service in {'managed-identity','network','iam-role-binding','load-balancer','vpn-gateway','acr'}:
        require(f'- {service}' in delivery, f'PR real Plan matrix missing immediately-planable service {service}')
    for stack in (
        'workloads/managed-identity', 'platform/connectivity', 'workloads/iam-role-binding',
        'workloads/load-balancer', 'workloads/vpn-gateway', 'platform/acr', 'workloads/storage',
        'workloads/key-vault', 'workloads/service-bus', 'workloads/managed-redis', 'workloads/postgresql-flexible',
    ):
        require(stack in delivery, f'Delivery Terraform validation missing {stack}')

    print('IaC REAL PLAN COVERAGE: PASSED')
    print('active_catalog_real_plan_matrix=11/11')
    print('pr_real_plan_matrix=managed-identity,network,iam-role-binding,load-balancer,vpn-gateway,acr')
    print('private-workload_real_plan_gate=requires_applied_platform_foundation')


if __name__ == '__main__':
    main()
