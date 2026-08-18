from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def fail(message: str) -> None:
    raise SystemExit(message)


def load(path: Path):
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--application", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    application = load(args.application)
    if application.get("apiVersion") != "platform.ci/v1" or application.get("kind") != "Application":
        fail("invalid application definition")

    spec = application["spec"]
    profile_name = spec["buildProfile"]
    profile_path = ROOT / "ci-catalog" / profile_name / "profile.json"
    if not profile_path.is_file():
        fail(f"unknown build profile: {profile_name}")

    profile = load(profile_path)
    build = profile["spec"]
    artifact = spec["artifact"]

    resolved = {
        "application": application["metadata"]["name"],
        "owner": application["metadata"]["owner"],
        "buildProfile": profile_name,
        "buildImage": build["buildImage"],
        "dependencyProxy": build["dependencyProxy"],
        "verifyCommand": build["commands"]["verify"],
        "packageCommand": build["commands"]["package"],
        "requiredControls": build["requiredControls"],
        "artifactType": artifact["type"],
        "artifactRepository": artifact["repository"],
        "dockerfile": artifact.get("dockerfile", "Dockerfile"),
        "releaseProfile": spec["deployment"].get("releaseProfile"),
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(resolved, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(resolved, indent=2))


if __name__ == "__main__":
    main()
