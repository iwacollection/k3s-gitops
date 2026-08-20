from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REPO = ROOT.parent


def fail(message: str) -> None:
    raise SystemExit(message)


def load(path: Path):
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def safe_relative_path(value: str, label: str) -> Path:
    path = Path(value)
    if path.is_absolute() or ".." in path.parts:
        fail(f"unsafe {label}: {value}")
    normalized = Path(*[part for part in path.parts if part not in {"", "."}])
    return normalized if normalized.parts else Path(".")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--application", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    application = load(args.application)
    if application.get("apiVersion") != "platform.ci/v1" or application.get("kind") != "Application":
        fail("invalid application definition")

    spec = application["spec"]
    source_path = safe_relative_path(spec.get("sourcePath", "."), "application sourcePath")
    source = (REPO / source_path).resolve()
    try:
        source.relative_to(REPO.resolve())
    except ValueError:
        fail(f"application sourcePath escapes repository: {source_path}")
    if not source.is_dir():
        fail(f"application sourcePath does not exist or is not a directory: {source_path}")

    profile_name = spec["buildProfile"]
    profile_path = ROOT / "ci-catalog" / profile_name / "profile.json"
    if not profile_path.is_file():
        fail(f"unknown build profile: {profile_name}")

    profile = load(profile_path)
    build = profile["spec"]
    commands = build["commands"]
    artifact = spec["artifact"]

    dockerfile = safe_relative_path(artifact.get("dockerfile", "Dockerfile"), "artifact dockerfile")
    dockerfile_path = (source / dockerfile).resolve()
    try:
        dockerfile_path.relative_to(source)
    except ValueError:
        fail(f"artifact dockerfile escapes application sourcePath: {dockerfile}")
    if artifact.get("type") == "container" and not dockerfile_path.is_file():
        fail(f"container Dockerfile does not exist under application sourcePath: {dockerfile_path.relative_to(REPO)}")

    repository = str(artifact["repository"])
    if not re.fullmatch(r"[a-z0-9]+(?:[._-][a-z0-9]+)*(?:/[a-z0-9]+(?:[._-][a-z0-9]+)*)*", repository):
        fail(f"unsafe artifact repository name: {repository}")

    resolved = {
        "application": application["metadata"]["name"],
        "owner": application["metadata"]["owner"],
        "sourcePath": source_path.as_posix(),
        "buildProfile": profile_name,
        "buildImage": build["buildImage"],
        "dependencyProxy": build["dependencyProxy"],
        "prepareCommand": commands.get("prepare", "true"),
        "verifyCommand": commands["verify"],
        "packageCommand": commands["package"],
        "cacheKeyInputs": build.get("cacheKeyInputs", []),
        "requiredControls": build["requiredControls"],
        "artifactType": artifact["type"],
        "artifactRepository": repository,
        "dockerfile": dockerfile.as_posix(),
        "releaseProfile": spec["deployment"].get("releaseProfile"),
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(resolved, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(resolved, indent=2))


if __name__ == "__main__":
    main()
