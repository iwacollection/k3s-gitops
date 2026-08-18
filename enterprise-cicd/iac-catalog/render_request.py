from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent


def load(path: Path) -> Any:
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def fail(message: str) -> None:
    raise SystemExit(message)


def validate_scalar(name: str, value: Any, rule: dict[str, Any]) -> None:
    if "const" in rule and value != rule["const"]:
        fail(f"{name}: value must be {rule['const']!r}")
    if "enum" in rule and value not in rule["enum"]:
        fail(f"{name}: value {value!r} is not allowed; allowed={rule['enum']}")

    expected = rule.get("type")
    if expected == "integer" and (not isinstance(value, int) or isinstance(value, bool)):
        fail(f"{name}: integer required")
    if expected == "string" and not isinstance(value, str):
        fail(f"{name}: string required")
    if expected == "boolean" and not isinstance(value, bool):
        fail(f"{name}: boolean required")

    if isinstance(value, int) and not isinstance(value, bool):
        if "minimum" in rule and value < rule["minimum"]:
            fail(f"{name}: minimum is {rule['minimum']}")
        if "maximum" in rule and value > rule["maximum"]:
            fail(f"{name}: maximum is {rule['maximum']}")


def validate_request_envelope(request: dict[str, Any]) -> None:
    if request.get("apiVersion") != "platform.iac/v1":
        fail("apiVersion must be platform.iac/v1")
    if request.get("kind") != "InfrastructureRequest":
        fail("kind must be InfrastructureRequest")

    metadata = request.get("metadata") or {}
    spec = request.get("spec") or {}
    for key in ("name", "owner", "application"):
        if not metadata.get(key):
            fail(f"metadata.{key} is required")
    for key in ("environment", "region", "service", "templateVersion", "parameters"):
        if key not in spec:
            fail(f"spec.{key} is required")

    if spec["environment"] not in {"dev", "test", "prod"}:
        fail("spec.environment must be dev, test or prod")
    if not re.fullmatch(r"v[0-9]+", spec["templateVersion"]):
        fail("spec.templateVersion must look like v1")
    if not isinstance(spec["parameters"], dict):
        fail("spec.parameters must be an object")


def validate_parameters(parameters: dict[str, Any], schema: dict[str, Any]) -> None:
    allowed = schema.get("properties", {})
    required = set(schema.get("required", []))
    unknown = set(parameters) - set(allowed)
    missing = required - set(parameters)
    if unknown:
        fail(f"unsupported request parameters: {sorted(unknown)}")
    if missing:
        fail(f"missing request parameters: {sorted(missing)}")
    for name, value in parameters.items():
        validate_scalar(name, value, allowed[name])


def apply_policy(environment: str, parameters: dict[str, Any], policy: dict[str, Any]) -> None:
    env_policy = policy.get(environment)
    if not env_policy:
        fail(f"no policy exists for environment {environment}")

    if "allowedSku" in env_policy and parameters.get("sku") not in env_policy["allowedSku"]:
        fail(f"{environment}: sku {parameters.get('sku')!r} is not allowed")
    if env_policy.get("requirePublicNetworkDisabled") and parameters.get("publicNetworkAccess") != "Disabled":
        fail(f"{environment}: public network access must be Disabled")


def acr_tfvars(request: dict[str, Any], parameters: dict[str, Any], name_prefix: str) -> dict[str, Any]:
    metadata = request["metadata"]
    spec = request["spec"]
    app = re.sub(r"[^a-z0-9]", "", metadata["application"].lower())
    env = spec["environment"]
    digest = hashlib.sha256(f"{metadata['name']}:{app}:{env}".encode()).hexdigest()[:6]
    acr_name = f"{name_prefix}{app}{env}{digest}".lower()[:50]
    if len(acr_name) < 5:
        fail("generated ACR name is too short")

    tags = {
        "application": metadata["application"],
        "environment": env,
        "owner": metadata["owner"],
        "managed_by": "iac-catalog",
        "iac_request": metadata["name"],
    }
    if metadata.get("costCenter"):
        tags["cost_center"] = metadata["costCenter"]

    return {
        "resource_group_name": f"rg-{metadata['application']}-{env}",
        "location": spec["region"],
        "acr_name": acr_name,
        "sku": parameters["sku"],
        "public_network_access_enabled": parameters["publicNetworkAccess"] == "Enabled",
        "retention_days": parameters.get("retentionDays", 30),
        "tags": tags,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Render an IaC catalog request into Terraform variables.")
    parser.add_argument("--request", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--name-prefix", default="plat")
    args = parser.parse_args()

    request = load(args.request)
    validate_request_envelope(request)

    spec = request["spec"]
    service_dir = ROOT / "services" / spec["service"] / spec["templateVersion"]
    if not service_dir.is_dir():
        fail(f"unknown catalog service/version: {spec['service']}/{spec['templateVersion']}")

    catalog = load(service_dir / "catalog.json")
    defaults = load(service_dir / catalog["defaults"])
    schema = load(service_dir / catalog["requestSchema"])
    policy = load(service_dir / catalog["policy"])

    parameters = dict(defaults)
    parameters.update(spec["parameters"])
    validate_parameters(parameters, schema)
    apply_policy(spec["environment"], parameters, policy)

    if spec["service"] == "acr":
        tfvars = acr_tfvars(request, parameters, args.name_prefix)
    else:
        fail(f"renderer not implemented for service {spec['service']}")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(tfvars, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    print(json.dumps({
        "request": request["metadata"]["name"],
        "service": f"{spec['service']}/{spec['templateVersion']}",
        "environment": spec["environment"],
        "rootStack": catalog["rootStack"],
        "tfvars": str(args.output),
    }, indent=2))


if __name__ == "__main__":
    main()
