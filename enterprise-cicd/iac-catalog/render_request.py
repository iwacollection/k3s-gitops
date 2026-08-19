from __future__ import annotations

import argparse
import hashlib
import ipaddress
import json
import re
import uuid
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent
BINDINGS = ROOT.parent / "contracts" / "environment-bindings.json"


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
    if expected == "number" and (not isinstance(value, (int, float)) or isinstance(value, bool)):
        fail(f"{name}: number required")
    if expected == "string" and not isinstance(value, str):
        fail(f"{name}: string required")
    if expected == "boolean" and not isinstance(value, bool):
        fail(f"{name}: boolean required")

    if isinstance(value, (int, float)) and not isinstance(value, bool):
        if "minimum" in rule and value < rule["minimum"]:
            fail(f"{name}: minimum is {rule['minimum']}")
        if "maximum" in rule and value > rule["maximum"]:
            fail(f"{name}: maximum is {rule['maximum']}")
    if isinstance(value, str):
        if "minLength" in rule and len(value) < rule["minLength"]:
            fail(f"{name}: minimum length is {rule['minLength']}")
        if "pattern" in rule and not re.fullmatch(rule["pattern"], value):
            fail(f"{name}: value does not match required pattern")


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
    if env_policy.get("enabled") is False:
        fail(f"{environment}: service is disabled: {env_policy.get('reason', 'platform policy')}")

    if "allowedSku" in env_policy and parameters.get("sku") not in env_policy["allowedSku"]:
        fail(f"{environment}: sku {parameters.get('sku')!r} is not allowed")
    if "allowedReplication" in env_policy and parameters.get("replication") not in env_policy["allowedReplication"]:
        fail(f"{environment}: replication {parameters.get('replication')!r} is not allowed")
    if "allowedVersions" in env_policy and parameters.get("version") not in env_policy["allowedVersions"]:
        fail(f"{environment}: version {parameters.get('version')!r} is not allowed")
    for name, values in env_policy.get("allowedValues", {}).items():
        if parameters.get(name) not in values:
            fail(f"{environment}: {name}={parameters.get(name)!r} is not allowed; allowed={values}")
    for name, expected in env_policy.get("requiredEquals", {}).items():
        if parameters.get(name) != expected:
            fail(f"{environment}: {name} must equal {expected!r}")
    if env_policy.get("requirePublicNetworkDisabled") and parameters.get("publicNetworkAccess") != "Disabled":
        fail(f"{environment}: public network access must be Disabled")
    if env_policy.get("requireSharedKeyDisabled") and parameters.get("sharedKeyAccess") is not False:
        fail(f"{environment}: Shared Key access must be disabled")
    if env_policy.get("requireBlobVersioning") and parameters.get("blobVersioning") is not True:
        fail(f"{environment}: blob versioning must be enabled")
    if "minDeleteRetentionDays" in env_policy and parameters.get("deleteRetentionDays", 0) < env_policy["minDeleteRetentionDays"]:
        fail(f"{environment}: delete retention must be at least {env_policy['minDeleteRetentionDays']} days")
    if "minBackupRetentionDays" in env_policy and parameters.get("backupRetentionDays", 0) < env_policy["minBackupRetentionDays"]:
        fail(f"{environment}: backup retention must be at least {env_policy['minBackupRetentionDays']} days")
    if env_policy.get("requirePurgeProtection") and parameters.get("purgeProtection") is not True:
        fail(f"{environment}: purge protection must be enabled")
    if env_policy.get("requireLocalAuthDisabled") and parameters.get("localAuth") is not False:
        fail(f"{environment}: local authentication must be disabled")
    if env_policy.get("requireGeoRedundantBackup") and parameters.get("geoRedundantBackup") is not True:
        fail(f"{environment}: geo-redundant backup must be enabled")
    if env_policy.get("requireHighAvailability"):
        if "highAvailability" in parameters and parameters["highAvailability"] is not True:
            fail(f"{environment}: high availability must be enabled")
        if "highAvailabilityMode" in parameters and parameters["highAvailabilityMode"] == "Disabled":
            fail(f"{environment}: high availability mode must not be Disabled")


def compact(value: str) -> str:
    return re.sub(r"[^a-z0-9]", "", value.lower())


def slug(value: str) -> str:
    result = re.sub(r"[^a-z0-9-]+", "-", value.lower()).strip("-")
    return re.sub(r"-+", "-", result)


def suffix(request: dict[str, Any]) -> str:
    metadata = request["metadata"]
    env = request["spec"]["environment"]
    return hashlib.sha256(f"{metadata['name']}:{metadata['application']}:{env}".encode()).hexdigest()[:6]


def tags(request: dict[str, Any]) -> dict[str, str]:
    metadata = request["metadata"]
    result = {
        "application": metadata["application"],
        "environment": request["spec"]["environment"],
        "owner": metadata["owner"],
        "managed_by": "iac-catalog",
        "iac_request": metadata["name"],
    }
    if metadata.get("costCenter"):
        result["cost_center"] = metadata["costCenter"]
    return result


def common(request: dict[str, Any]) -> dict[str, Any]:
    app = slug(request["metadata"]["application"])
    env = request["spec"]["environment"]
    return {
        "resource_group_name": f"rg-{app}-{env}",
        "location": request["spec"]["region"],
        "tags": tags(request),
    }


def network_binding(request: dict[str, Any], service: str, delegated: bool = False) -> dict[str, str]:
    env = request["spec"]["environment"]
    bindings = load(BINDINGS)
    try:
        network = bindings["environments"][env]["network"]
        zone = network["dnsZones"][service]
    except KeyError as exc:
        fail(f"missing platform network binding for {env}/{service}: {exc}")
    result = {
        "network_resource_group_name": network["resourceGroup"],
        "virtual_network_name": network["virtualNetwork"],
        "private_dns_zone_name": zone,
    }
    if delegated:
        result["delegated_subnet_name"] = network["postgresDelegatedSubnet"]
    else:
        result["private_endpoint_subnet_name"] = network["privateEndpointSubnet"]
    return result


def parse_private_ipv4_cidr(name: str, value: str) -> ipaddress.IPv4Network:
    try:
        network = ipaddress.ip_network(value, strict=True)
    except ValueError as exc:
        fail(f"{name}: invalid CIDR: {exc}")
    if not isinstance(network, ipaddress.IPv4Network):
        fail(f"{name}: only IPv4 is supported")
    private_ranges = (
        ipaddress.ip_network("10.0.0.0/8"),
        ipaddress.ip_network("172.16.0.0/12"),
        ipaddress.ip_network("192.168.0.0/16"),
    )
    if not any(network.subnet_of(parent) for parent in private_ranges):
        fail(f"{name}: only RFC1918 private address space is allowed")
    return network


def require_guid(name: str, value: str) -> str:
    try:
        return str(uuid.UUID(value))
    except ValueError:
        fail(f"{name}: valid GUID required")


def require_resource_group_or_child_scope(name: str, value: str) -> str:
    pattern = r"^/subscriptions/([0-9a-fA-F-]{36})/resourceGroups/([A-Za-z0-9._()\-]+)(/providers/.+)?$"
    match = re.fullmatch(pattern, value)
    if not match:
        fail(f"{name}: must be an Azure resource-group scope or a child resource scope")
    require_guid(f"{name}.subscriptionId", match.group(1))
    lowered = value.lower()
    if "/providers/microsoft.authorization/roleassignments/" in lowered:
        fail(f"{name}: role-assignment resource scopes are forbidden")
    if "/providers/microsoft.authorization/roledefinitions/" in lowered:
        fail(f"{name}: role-definition resource scopes are forbidden")
    return value


def require_subnet_resource_id(name: str, value: str) -> str:
    pattern = (
        r"^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[A-Za-z0-9._()\-]+/"
        r"providers/Microsoft\.Network/virtualNetworks/[^/]+/subnets/[^/]+$"
    )
    if not re.fullmatch(pattern, value, re.IGNORECASE):
        fail(f"{name}: Azure subnet resource ID required")
    return value


def acr_tfvars(request: dict[str, Any], parameters: dict[str, Any], name_prefix: str) -> dict[str, Any]:
    result = common(request)
    app = compact(request["metadata"]["application"])
    env = request["spec"]["environment"]
    name = f"{compact(name_prefix)}{app}{env}{suffix(request)}"[:50]
    if len(name) < 5:
        fail("generated ACR name is too short")
    result.update({
        "acr_name": name,
        "sku": parameters["sku"],
        "public_network_access_enabled": parameters["publicNetworkAccess"] == "Enabled",
        "retention_days": parameters.get("retentionDays", 30),
    })
    return result


def storage_tfvars(request: dict[str, Any], parameters: dict[str, Any]) -> dict[str, Any]:
    result = common(request)
    app = compact(request["metadata"]["application"])
    env = request["spec"]["environment"]
    name = f"st{app}{env}{suffix(request)}"[:24]
    result.update({
        "storage_account_name": name,
        "replication_type": parameters["replication"],
        "access_tier": parameters["accessTier"],
        "public_network_access_enabled": parameters["publicNetworkAccess"] == "Enabled",
        "blob_versioning_enabled": parameters["blobVersioning"],
        "delete_retention_days": parameters["deleteRetentionDays"],
    })
    return result


def key_vault_tfvars(request: dict[str, Any], parameters: dict[str, Any]) -> dict[str, Any]:
    result = common(request)
    app = compact(request["metadata"]["application"])[:8] or "app"
    env = request["spec"]["environment"]
    result.update({
        "key_vault_name": f"kv-{app}-{env}-{suffix(request)}"[:24].rstrip("-"),
        "sku_name": parameters["sku"].lower(),
        "purge_protection_enabled": parameters["purgeProtection"],
        "soft_delete_retention_days": parameters["softDeleteRetentionDays"],
        "public_network_access_enabled": parameters["publicNetworkAccess"] == "Enabled",
    })
    result.update(network_binding(request, "key-vault"))
    return result


def managed_identity_tfvars(request: dict[str, Any], parameters: dict[str, Any]) -> dict[str, Any]:
    result = common(request)
    app = slug(request["metadata"]["application"])
    env = request["spec"]["environment"]
    result["identity_name"] = f"id-{app}-{env}-{suffix(request)}"[:128].rstrip("-")
    result["tags"] = {**result["tags"], "identity_purpose": parameters["purpose"]}
    return result


def network_tfvars(request: dict[str, Any], parameters: dict[str, Any]) -> dict[str, Any]:
    vnet = parse_private_ipv4_cidr("addressSpace", parameters["addressSpace"])
    subnet = parse_private_ipv4_cidr("subnetPrefix", parameters["subnetPrefix"])
    if not subnet.subnet_of(vnet) or subnet.prefixlen <= vnet.prefixlen:
        fail("subnetPrefix: must be a proper subnet of addressSpace")

    result = common(request)
    app = slug(request["metadata"]["application"])
    env = request["spec"]["environment"]
    subnet_name = slug(parameters["subnetName"])
    result.update({
        "virtual_network_name": f"vnet-{app}-{env}-{suffix(request)}"[:64].rstrip("-"),
        "address_space": [str(vnet)],
        "subnets": {
            subnet_name: {
                "address_prefixes": [str(subnet)],
                "service_endpoints": [],
            }
        },
        "network_security_groups": {},
        "route_tables": {},
        "nat_gateway": None,
        "private_dns_zone_names": [],
    })
    result["tags"] = {**result["tags"], "network_cost_profile": "vnet-subnet-only"}
    return result


def iam_role_binding_tfvars(request: dict[str, Any], parameters: dict[str, Any]) -> dict[str, Any]:
    principal_id = require_guid("principalId", parameters["principalId"])
    scope = require_resource_group_or_child_scope("scopeResourceId", parameters["scopeResourceId"])
    return {
        "assignments": {
            slug(request["metadata"]["name"]): {
                "scope": scope,
                "role_definition_name": parameters["roleName"],
                "principal_id": principal_id,
                "principal_type": parameters["principalType"],
                "description": f"IaC request {request['metadata']['name']} owned by {request['metadata']['owner']}",
            }
        }
    }


def load_balancer_tfvars(request: dict[str, Any], parameters: dict[str, Any]) -> dict[str, Any]:
    result = common(request)
    app = slug(request["metadata"]["application"])
    env = request["spec"]["environment"]
    exposure = parameters["exposure"]
    subnet_resource_id = parameters.get("subnetResourceId", "")
    if exposure == "internal":
        require_subnet_resource_id("subnetResourceId", subnet_resource_id)
    elif subnet_resource_id:
        fail("subnetResourceId must be empty for a public load balancer")

    result.update({
        "load_balancer_name": f"lb-{app}-{env}-{suffix(request)}"[:80].rstrip("-"),
        "exposure": exposure,
        "subnet_id": subnet_resource_id or None,
        "frontend_private_ip_address": parameters.get("frontendPrivateIpAddress") or None,
        "frontend_port": parameters["frontendPort"],
        "backend_port": parameters["backendPort"],
        "protocol": parameters["protocol"],
        "probe_protocol": parameters["probeProtocol"],
        "probe_port": parameters["probePort"],
        "probe_request_path": parameters.get("probeRequestPath") or None,
        "idle_timeout_in_minutes": parameters["idleTimeoutMinutes"],
        "tags": {**result["tags"], "billing_impact": "load-balancer"},
    })
    return result


def vpn_gateway_tfvars(request: dict[str, Any], parameters: dict[str, Any]) -> dict[str, Any]:
    vnet = parse_private_ipv4_cidr("addressSpace", parameters["addressSpace"])
    gateway_subnet = parse_private_ipv4_cidr("gatewaySubnetPrefix", parameters["gatewaySubnetPrefix"])
    if not gateway_subnet.subnet_of(vnet) or gateway_subnet.prefixlen <= vnet.prefixlen:
        fail("gatewaySubnetPrefix: must be a proper subnet of addressSpace")

    result = common(request)
    app = slug(request["metadata"]["application"])
    env = request["spec"]["environment"]
    result.update({
        "virtual_network_name": f"vnet-vpn-{app}-{env}-{suffix(request)}"[:64].rstrip("-"),
        "address_space": [str(vnet)],
        "gateway_subnet_prefix": str(gateway_subnet),
        "public_ip_name": f"pip-vpngw-{app}-{env}-{suffix(request)}"[:80].rstrip("-"),
        "gateway_name": f"vpngw-{app}-{env}-{suffix(request)}"[:80].rstrip("-"),
        "sku": parameters["sku"],
        "bgp_enabled": parameters["bgpEnabled"],
        "active_active": False,
        "tags": {**result["tags"], "billing_impact": "vpn-gateway", "secret_mode": "no-psk-in-git"},
    })
    return result


def service_bus_tfvars(request: dict[str, Any], parameters: dict[str, Any]) -> dict[str, Any]:
    result = common(request)
    app = compact(request["metadata"]["application"])[:24] or "app"
    env = request["spec"]["environment"]
    result.update({
        "service_bus_name": f"sb-{app}-{env}-{suffix(request)}"[:50].rstrip("-"),
        "sku": parameters["sku"],
        "capacity": parameters["capacity"],
        "public_network_access_enabled": parameters["publicNetworkAccess"] == "Enabled",
    })
    result.update(network_binding(request, "service-bus"))
    return result


def managed_redis_tfvars(request: dict[str, Any], parameters: dict[str, Any]) -> dict[str, Any]:
    result = common(request)
    app = slug(request["metadata"]["application"])
    env = request["spec"]["environment"]
    result.update({
        "redis_name": f"redis-{app}-{env}-{suffix(request)}"[:63].rstrip("-"),
        "sku_name": parameters["sku"],
        "high_availability_enabled": parameters["highAvailability"],
        "public_network_access": parameters["publicNetworkAccess"],
        "clustering_policy": parameters["clusteringPolicy"],
        "eviction_policy": parameters["evictionPolicy"],
        "persistence_redis_database_backup_frequency": None if parameters["rdbBackupFrequency"] == "Disabled" else parameters["rdbBackupFrequency"],
    })
    result.update(network_binding(request, "managed-redis"))
    return result


def postgresql_flexible_tfvars(request: dict[str, Any], parameters: dict[str, Any]) -> dict[str, Any]:
    result = common(request)
    app = slug(request["metadata"]["application"])
    env = request["spec"]["environment"]
    result.update({
        "postgresql_server_name": f"pg-{app}-{env}-{suffix(request)}"[:63].rstrip("-"),
        "postgresql_version": parameters["version"],
        "sku_name": parameters["sku"],
        "storage_mb": parameters["storageMb"],
        "storage_tier": parameters["storageTier"],
        "backup_retention_days": parameters["backupRetentionDays"],
        "geo_redundant_backup_enabled": parameters["geoRedundantBackup"],
        "auto_grow_enabled": parameters["autoGrow"],
        "high_availability_mode": None if parameters["highAvailabilityMode"] == "Disabled" else parameters["highAvailabilityMode"],
    })
    result.update(network_binding(request, "postgresql-flexible", delegated=True))
    return result


RENDERERS = {
    "acr": acr_tfvars,
    "storage": storage_tfvars,
    "key-vault": key_vault_tfvars,
    "managed-identity": managed_identity_tfvars,
    "network": network_tfvars,
    "iam-role-binding": iam_role_binding_tfvars,
    "load-balancer": load_balancer_tfvars,
    "vpn-gateway": vpn_gateway_tfvars,
    "service-bus": service_bus_tfvars,
    "managed-redis": managed_redis_tfvars,
    "postgresql-flexible": postgresql_flexible_tfvars,
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

    renderer = RENDERERS.get(spec["service"])
    if not renderer:
        fail(f"renderer not implemented for service {spec['service']}")
    tfvars = renderer(request, parameters, args.name_prefix) if spec["service"] == "acr" else renderer(request, parameters)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(tfvars, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "request": request["metadata"]["name"],
        "service": f"{spec['service']}/{spec['templateVersion']}",
        "environment": spec["environment"],
        "lifecycle": catalog["lifecycle"],
        "rootStack": catalog["rootStack"],
        "tfvars": str(args.output),
    }, indent=2))


if __name__ == "__main__":
    main()
