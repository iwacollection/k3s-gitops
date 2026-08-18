from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path

REQUEST_ROOT = Path("enterprise-cicd/iac-requests")
ENVIRONMENTS = ("dev", "test", "prod")


def run_git(*args: str) -> str:
    return subprocess.check_output(["git", *args], text=True).strip()


def matrix_key(environment: str, service: str, request_name: str) -> str:
    raw = f"{environment}_{service}_{request_name}"
    value = re.sub(r"[^A-Za-z0-9_]", "_", raw)
    if not value or not value[0].isalpha():
        value = f"r_{value}"
    return value[:100]


def load_request(path: Path) -> dict:
    with path.open(encoding="utf-8") as handle:
        data = json.load(handle)
    if data.get("apiVersion") != "platform.iac/v1" or data.get("kind") != "InfrastructureRequest":
        raise SystemExit(f"invalid InfrastructureRequest: {path}")
    return data


def main() -> None:
    parser = argparse.ArgumentParser(description="Discover changed developer IaC requests and emit Azure Pipelines matrices.")
    parser.add_argument("--base-ref", required=True)
    parser.add_argument("--head-ref", default="HEAD")
    parser.add_argument("--azure-output", action="store_true")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    diff = run_git("diff", "--name-status", "--find-renames", args.base_ref, args.head_ref, "--", str(REQUEST_ROOT))
    matrices: dict[str, dict[str, dict[str, str]]] = {env: {} for env in ENVIRONMENTS}
    changed: list[str] = []

    for line in diff.splitlines():
        if not line.strip():
            continue
        fields = line.split("\t")
        status = fields[0]
        if status.startswith("D") or status.startswith("R"):
            raise SystemExit(
                "IaC request deletion/rename is not an implicit destroy operation. "
                "Use the governed retirement workflow instead: " + line
            )
        path_text = fields[-1]
        path = Path(path_text)
        if path.suffix != ".json":
            continue
        try:
            relative = path.relative_to(REQUEST_ROOT)
        except ValueError as exc:
            raise SystemExit(f"request outside governed root: {path}") from exc
        if len(relative.parts) < 2 or relative.parts[0] not in ENVIRONMENTS:
            raise SystemExit(f"request path must be iac-requests/<dev|test|prod>/...json: {path}")

        environment = relative.parts[0]
        request = load_request(path)
        metadata = request.get("metadata", {})
        spec = request.get("spec", {})
        request_name = metadata.get("name", "")
        service = spec.get("service", "")
        declared_environment = spec.get("environment", "")
        if declared_environment != environment:
            raise SystemExit(f"request environment/path mismatch: {path}: {declared_environment} != {environment}")
        if not request_name or not service:
            raise SystemExit(f"request missing metadata.name/spec.service: {path}")

        key = matrix_key(environment, service, request_name)
        matrices[environment][key] = {
            "enabled": "true",
            "requestPath": path.as_posix(),
            "requestName": request_name,
            "service": service,
            "environment": environment,
            "planArtifactName": f"tfplan-{environment}-{service}-{request_name}",
        }
        changed.append(path.as_posix())

    for environment in ENVIRONMENTS:
        if not matrices[environment]:
            matrices[environment][f"no_{environment}_changes"] = {
                "enabled": "false",
                "requestPath": "",
                "requestName": "none",
                "service": "none",
                "environment": environment,
                "planArtifactName": f"tfplan-{environment}-none",
            }

    result = {"changedRequests": changed, "matrices": matrices}
    rendered = json.dumps(result, separators=(",", ":"))
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")

    if args.azure_output:
        for environment in ENVIRONMENTS:
            matrix = json.dumps(matrices[environment], separators=(",", ":"))
            print(f"##vso[task.setvariable variable={environment}Matrix;isOutput=true]{matrix}")
        print(f"##vso[task.setvariable variable=changedCount;isOutput=true]{len(changed)}")

    print(rendered)


if __name__ == "__main__":
    main()
