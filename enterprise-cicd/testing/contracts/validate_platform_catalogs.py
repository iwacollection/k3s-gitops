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

print("Platform CI/CD catalogs are valid.")
