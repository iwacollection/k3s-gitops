from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def main() -> int:
    errors: list[str] = []
    versions_path = ROOT / "build-images" / "versions.json"
    registry = load(versions_path)
    images = registry.get("images", {})

    required_images = {
        "java21-maven:v1",
        "python-uv:v1",
        "go-builder:v1",
        "cpp-cmake-conan:v1",
    }
    if not required_images.issubset(images):
        fail(errors, f"missing required build images: {sorted(required_images - set(images))}")

    for name, cfg in images.items():
        if name.endswith(":latest") or ":" not in name:
            fail(errors, f"build image must use an explicit version tag: {name}")
        context = Path(cfg["context"])
        dockerfile = ROOT.parent / context / cfg.get("dockerfile", "Dockerfile")
        if not dockerfile.is_file():
            fail(errors, f"build image Dockerfile does not exist: {dockerfile}")

    mandatory_controls = {"unit-test", "secret-scan", "sca", "sast", "sbom", "container-scan", "sign", "provenance"}
    profile_root = ROOT / "ci-catalog"
    profiles = list(profile_root.glob("*/*/profile.json"))
    if not profiles:
        fail(errors, "no CI build profiles found")

    for profile_path in profiles:
        profile = load(profile_path)
        spec = profile.get("spec", {})
        image = spec.get("buildImage")
        if image not in images:
            fail(errors, f"profile references unregistered build image: {profile_path}: {image}")
        controls = set(spec.get("requiredControls", []))
        missing = mandatory_controls - controls
        if missing:
            fail(errors, f"profile missing mandatory controls {sorted(missing)}: {profile_path}")
        if not spec.get("cacheKeyInputs"):
            fail(errors, f"profile must declare cacheKeyInputs: {profile_path}")
        if spec.get("dependencyProxy") not in {"maven", "pypi", "go", "cpp"}:
            fail(errors, f"profile has unknown dependency proxy: {profile_path}")

    security = load(ROOT / "security" / "ci-security-policy.json")
    container = security["spec"]["container"]
    for key in ("vulnerabilityScan", "sbom", "provenance", "signature"):
        if container.get(key, {}).get("required") is not True:
            fail(errors, f"container security control must be required: {key}")

    dependency = load(ROOT / "dependency-proxy" / "policy.json")
    if dependency["rules"].get("sharedWritableWorkspaceAllowed") is not False:
        fail(errors, "shared writable build workspaces must remain forbidden")
    if dependency["rules"].get("cacheIsOptimizationNotSourceOfTruth") is not True:
        fail(errors, "dependency cache must not become source of truth")

    if errors:
        print("BUILD PLATFORM VALIDATION: FAILED")
        for error in errors:
            print(f"- {error}")
        return 1

    print("BUILD PLATFORM VALIDATION: PASSED")
    print(f"registered images: {len(images)}")
    print(f"validated profiles: {len(profiles)}")
    print("security: source + container controls required")
    print("cache: lock/profile scoped; shared writable workspace forbidden")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
