#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

REPO = Path(__file__).resolve().parents[2]
DECOMMISSION_ROOT = REPO / "enterprise-cicd" / "iac-decommission" / "dev"
SUPPORTED_SERVICES = {"managed-identity", "network"}


def fail(message: str) -> None:
    raise SystemExit(message)


def load(path: Path) -> Any:
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def repo_relative(path: Path) -> str:
    return path.resolve().relative_to(REPO).as_posix()


def validate(tombstone_path: Path) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any]]:
    tombstone_path = tombstone_path.resolve()
    try:
        tombstone_path.relative_to(DECOMMISSION_ROOT.resolve())
    except ValueError:
        fail("DEV decommission tombstone must live under enterprise-cicd/iac-decommission/dev")

    tombstone = load(tombstone_path)
    if tombstone.get("apiVersion") != "platform.iac/v1":
        fail("decommission apiVersion must be platform.iac/v1")
    if tombstone.get("kind") != "DecommissionRequest":
        fail("decommission kind must be DecommissionRequest")

    metadata = tombstone.get("metadata") or {}
    spec = tombstone.get("spec") or {}
    for key in ("name", "owner", "changeTicket", "reason"):
        if not metadata.get(key):
            fail(f"metadata.{key} is required")
    if len(str(metadata["reason"]).strip()) < 10:
        fail("metadata.reason must contain a meaningful decommission reason")
    if not re.fullmatch(r"CHG-[A-Za-z0-9._-]{3,64}", str(metadata["changeTicket"])):
        fail("metadata.changeTicket must look like CHG-1234")

    required_spec = {"environment", "requestPath", "requestName", "service", "confirmation"}
    if set(spec) != required_spec:
        fail(f"decommission spec must contain exactly {sorted(required_spec)}")
    if spec["environment"] != "dev":
        fail("DEV decommission only accepts spec.environment=dev")
    if spec["service"] not in SUPPORTED_SERVICES:
        fail(f"service is not activated for governed DEV decommission: {spec['service']}")

    request_path_text = str(spec["requestPath"])
    if not request_path_text.startswith("enterprise-cicd/iac-requests/dev/"):
        fail("spec.requestPath must reference a governed DEV InfrastructureRequest")
    if request_path_text.endswith(".example.json") or not request_path_text.endswith(".json"):
        fail("spec.requestPath must reference a non-example JSON request")

    request_path = (REPO / request_path_text).resolve()
    try:
        request_path.relative_to((REPO / "enterprise-cicd" / "iac-requests" / "dev").resolve())
    except ValueError:
        fail("spec.requestPath escapes the governed DEV request directory")
    if not request_path.is_file():
        fail("retired InfrastructureRequest must remain in Git for audit and deterministic destroy rendering")

    request = load(request_path)
    if request.get("apiVersion") != "platform.iac/v1" or request.get("kind") != "InfrastructureRequest":
        fail("referenced file is not a platform.iac/v1 InfrastructureRequest")

    request_meta = request.get("metadata") or {}
    request_spec = request.get("spec") or {}
    if request_spec.get("environment") != "dev":
        fail("referenced InfrastructureRequest is not DEV")
    if request_meta.get("name") != spec["requestName"]:
        fail("spec.requestName does not match referenced InfrastructureRequest")
    if request_spec.get("service") != spec["service"]:
        fail("spec.service does not match referenced InfrastructureRequest")
    if spec["confirmation"] != f"DESTROY {spec['requestName']}":
        fail(f"spec.confirmation must be exactly DESTROY {spec['requestName']}")

    duplicates: list[str] = []
    if DECOMMISSION_ROOT.is_dir():
        for candidate in sorted(DECOMMISSION_ROOT.glob("*.json")):
            data = load(candidate)
            if (data.get("spec") or {}).get("requestPath") == request_path_text:
                duplicates.append(repo_relative(candidate))
    if len(duplicates) != 1 or duplicates[0] != repo_relative(tombstone_path):
        fail(f"exactly one immutable tombstone is allowed per InfrastructureRequest: {duplicates}")

    version = request_spec.get("templateVersion")
    catalog_path = REPO / "enterprise-cicd" / "iac-catalog" / "services" / spec["service"] / str(version) / "catalog.json"
    if not catalog_path.is_file():
        fail("referenced request catalog service/version no longer exists")
    catalog = load(catalog_path)
    if catalog.get("lifecycle") != "active":
        fail("referenced catalog version must remain active during decommission")

    resolved = {
        "tombstone": repo_relative(tombstone_path),
        "requestPath": request_path_text,
        "requestName": spec["requestName"],
        "service": spec["service"],
        "templateVersion": version,
        "rootStack": catalog["rootStack"],
        "changeTicket": metadata["changeTicket"],
        "owner": metadata["owner"],
        "reason": metadata["reason"],
        "confirmation": spec["confirmation"],
        "environment": "dev",
        "retired": True,
    }
    return tombstone, request, resolved


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate an immutable governed DEV IaC decommission tombstone.")
    parser.add_argument("--tombstone", required=True, type=Path)
    parser.add_argument("--original-output", type=Path)
    parser.add_argument("--metadata-output", type=Path)
    args = parser.parse_args()

    _, request, resolved = validate(args.tombstone)

    if args.original_output:
        args.original_output.parent.mkdir(parents=True, exist_ok=True)
        args.original_output.write_text(json.dumps(request, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    if args.metadata_output:
        args.metadata_output.parent.mkdir(parents=True, exist_ok=True)
        args.metadata_output.write_text(json.dumps(resolved, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    print(json.dumps(resolved, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
