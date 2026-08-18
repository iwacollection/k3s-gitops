from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def load(path: Path):
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


iac_catalogs = {}
for path in (ROOT / "iac-catalog" / "services").glob("*/v*/catalog.json"):
    service = path.parents[1].name
    version = path.parent.name
    key = f"{service}/{version}"
    catalog = load(path)
    iac_catalogs[key] = catalog
    service_dir = path.parent
    require(catalog.get("service") == service, f"{key}: catalog service mismatch")
    require(catalog.get("version") == version, f"{key}: catalog version mismatch")
    require(catalog.get("lifecycle") in {"active", "preview"}, f"{key}: unsupported lifecycle")
    for field in ("requestSchema", "defaults", "policy"):
        require((service_dir / catalog[field]).is_file(), f"{key}: missing {field}")
    require((ROOT.parent / catalog["terraformModule"]).is_dir(), f"{key}: Terraform module does not exist")
    require((ROOT.parent / catalog["rootStack"]).is_dir(), f"{key}: root stack does not exist")

required_iac = {"acr/v1", "storage/v1", "key-vault/v1", "managed-identity/v1", "service-bus/v1"}
require(required_iac <= set(iac_catalogs), f"missing required IaC catalog products: {sorted(required_iac - set(iac_catalogs))}")

storage_policy = load(ROOT / "iac-catalog" / "services" / "storage" / "v1" / "policy.json")
require(storage_policy["prod"].get("requirePublicNetworkDisabled") is True, "storage PROD must require private-only public network setting")
require(storage_policy["prod"].get("requireSharedKeyDisabled") is True, "storage PROD must disable Shared Key")
require(storage_policy["prod"].get("requireBlobVersioning") is True, "storage PROD must require versioning")

for preview_service in ("key-vault", "service-bus"):
    catalog = iac_catalogs[f"{preview_service}/v1"]
    policy = load(ROOT / "iac-catalog" / "services" / preview_service / "v1" / "policy.json")
    require(catalog["lifecycle"] == "preview", f"{preview_service}: must remain preview until private networking is governed")
    require(policy["prod"].get("enabled") is False, f"{preview_service}: PROD must be blocked until private networking is governed")

require(iac_catalogs["managed-identity/v1"]["lifecycle"] == "active", "managed identity v1 should be active")

ci_profiles = {
    path.relative_to(ROOT / "ci-catalog").parent.as_posix(): load(path)
    for path in (ROOT / "ci-catalog").glob("*/*/profile.json")
}
require(
    {"java/springboot-maven-v1", "python/python-uv-v1", "go/go-service-v1", "cpp/cmake-conan-v1"}
    <= set(ci_profiles),
    "missing required CI profiles",
)

for name, profile in ci_profiles.items():
    require(profile.get("kind") == "BuildProfile", f"{name}: invalid BuildProfile kind")
    controls = set(profile["spec"].get("requiredControls", []))
    require({"unit-test", "sbom", "sign", "provenance"} <= controls, f"{name}: supply-chain controls missing")
    require(profile["spec"].get("buildImage"), f"{name}: buildImage is required")
    require(profile["spec"].get("dependencyProxy"), f"{name}: dependencyProxy is required")

release_profiles = {
    path.relative_to(ROOT / "release-catalog").parent.as_posix(): load(path)
    for path in (ROOT / "release-catalog").glob("*/*/profile.json")
}
require(
    {"rolling/rolling-v1", "canary/canary-v1", "blue-green/blue-green-v1"}
    <= set(release_profiles),
    "missing required release profiles",
)
for name, profile in release_profiles.items():
    require(profile.get("kind") == "ReleaseProfile", f"{name}: invalid ReleaseProfile kind")
    require("rollback" in profile["spec"], f"{name}: rollback policy is required")

application = load(ROOT / "application-definitions" / "payment-api.example.json")
require(application["spec"]["buildProfile"] in ci_profiles, "application references unknown build profile")
require(application["spec"]["deployment"]["releaseProfile"] in release_profiles, "application references unknown release profile")

release = load(ROOT / "release-requests" / "payment-api-to-prod.example.json")
require(release["spec"]["releaseProfile"] in release_profiles, "release request references unknown release profile")

promotion = load(ROOT / "promotion" / "policies" / "default.json")
transitions = set(promotion["spec"]["allowedTransitions"])
require(transitions == {"build->dev", "dev->test", "test->prod"}, "promotion path must be build -> dev -> test -> prod")
require(promotion["spec"].get("sameDigestRequired") is True, "promotion must require the same artifact digest")
require(promotion["spec"]["prod"].get("approvalRequired") is True, "production approval must be required")
require(promotion["spec"]["prod"].get("signedArtifactRequired") is True, "production must require signed artifacts")

rollback = load(ROOT / "promotion" / "rollback" / "default.json")
require(rollback["spec"].get("rebuildForbidden") is True, "rollback must not rebuild artifacts")
require(rollback["spec"].get("postRollbackVerificationRequired") is True, "post-rollback verification is required")

print("Platform IaC/CI/CD catalogs are valid.")
print(f"IaC products: {', '.join(sorted(iac_catalogs))}")
