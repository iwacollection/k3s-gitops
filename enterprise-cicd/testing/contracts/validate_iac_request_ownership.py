#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
REQUEST_ROOT = REPO / "enterprise-cicd" / "iac-requests" / "dev"
TOMBSTONE_ROOT = REPO / "enterprise-cicd" / "iac-decommission" / "dev"
RENDERER = REPO / "enterprise-cicd" / "iac-catalog" / "render_request.py"

NON_OWNING_SERVICES = {"iam-role-binding"}


def fail(message: str) -> None:
    raise SystemExit(message)


def validate_non_owning_request(*, relative: str, service: str, tfvars: dict) -> None:
    if service != "iam-role-binding":
        fail(f"unsupported non-owning Catalog service: {service} ({relative})")

    assignments = tfvars.get("assignments") or {}
    if not assignments:
        fail(f"IAM request rendered no assignments: {relative}")

    for name, assignment in assignments.items():
        scope = str((assignment or {}).get("scope") or "")
        principal_type = str((assignment or {}).get("principal_type") or "")
        if not scope:
            fail(f"IAM assignment has no scope: {relative} assignment={name}")
        normalized = scope.rstrip("/").lower()
        if normalized.count("/") <= 2 or "/resourcegroups/" not in normalized:
            fail(
                "IAM Catalog v1 may reference an existing resource-group/resource scope, "
                f"but subscription-root scope is forbidden: {relative} scope={scope}"
            )
        if principal_type != "ServicePrincipal":
            fail(
                f"IAM Catalog v1 must remain ServicePrincipal-only: {relative} "
                f"assignment={name} principalType={principal_type}"
            )


def main() -> None:
    retired: set[str] = set()
    if TOMBSTONE_ROOT.is_dir():
        for path in sorted(TOMBSTONE_ROOT.glob("*.json")):
            data = json.loads(path.read_text(encoding="utf-8"))
            request_path = (data.get("spec") or {}).get("requestPath")
            if request_path:
                retired.add(request_path)

    ownership: dict[str, list[dict[str, str]]] = {}
    active_count = 0
    non_owning_count = 0

    with tempfile.TemporaryDirectory(prefix="iac-ownership-") as tmp:
        tmpdir = Path(tmp)
        for request_path in sorted(REQUEST_ROOT.glob("*.json")):
            if request_path.name.endswith(".example.json"):
                continue
            relative = request_path.relative_to(REPO).as_posix()
            if relative in retired:
                continue

            request = json.loads(request_path.read_text(encoding="utf-8"))
            spec = request.get("spec") or {}
            metadata = request.get("metadata") or {}
            if spec.get("environment") != "dev":
                fail(f"non-DEV request found in DEV ownership scope: {relative}")

            service = str(spec.get("service") or "")
            output = tmpdir / f"{request_path.stem}.tfvars.json"
            subprocess.run(
                [
                    "python",
                    str(RENDERER),
                    "--request",
                    str(request_path),
                    "--output",
                    str(output),
                ],
                cwd=REPO,
                check=True,
                capture_output=True,
                text=True,
            )
            tfvars = json.loads(output.read_text(encoding="utf-8"))

            if service in NON_OWNING_SERVICES:
                validate_non_owning_request(
                    relative=relative,
                    service=service,
                    tfvars=tfvars,
                )
                non_owning_count += 1
                active_count += 1
                continue

            resource_group = tfvars.get("resource_group_name")
            if not resource_group:
                fail(f"request does not render a resource_group_name: {relative}")
            tags = tfvars.get("tags") or {}
            if tags.get("iac_request") != metadata.get("name"):
                fail(f"request ownership tag mismatch: {relative}")

            state_key = f"catalog/dev/{service}/{metadata.get('name')}.tfstate"
            ownership.setdefault(resource_group.lower(), []).append(
                {
                    "request": relative,
                    "requestName": str(metadata.get("name")),
                    "service": service,
                    "stateKey": state_key,
                }
            )
            active_count += 1

    collisions = {
        resource_group: owners
        for resource_group, owners in ownership.items()
        if len(owners) > 1
    }
    if collisions:
        fail(
            "multiple independent Terraform states would own the same Azure Resource Group; "
            "shared RG lifecycle is forbidden in Catalog v1: "
            + json.dumps(collisions, sort_keys=True)
        )

    print(
        f"IaC request ownership contract valid: active_requests={active_count}, "
        f"exclusive_resource_groups={len(ownership)}, non_owning_requests={non_owning_count}, "
        "collisions=0."
    )


if __name__ == "__main__":
    main()
