from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load(path: Path):
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def fail(message: str) -> None:
    raise SystemExit(message)


def main() -> None:
    parser = argparse.ArgumentParser(description="Render a governed release request into GitOps desired state.")
    parser.add_argument("--request", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    request = load(args.request)
    if request.get("apiVersion") != "platform.release/v1" or request.get("kind") != "Release":
        fail("invalid release request")

    metadata = request["metadata"]
    spec = request["spec"]
    transition = f"{spec['from']}->{spec['to']}"

    promotion = load(ROOT / "promotion" / "policies" / "default.json")
    if transition not in promotion["spec"]["allowedTransitions"]:
        fail(f"promotion transition is not allowed: {transition}")

    digest = spec["artifactDigest"]
    if not digest.startswith("sha256:") or len(digest) != 71:
        fail("release must reference an immutable sha256 digest")

    profile_path = ROOT / "release-catalog" / spec["releaseProfile"] / "profile.json"
    if not profile_path.is_file():
        fail(f"unknown release profile: {spec['releaseProfile']}")
    profile = load(profile_path)

    desired = {
        "apiVersion": "platform.gitops/v1",
        "kind": "ApplicationRelease",
        "metadata": {
            "application": metadata["application"],
            "owner": metadata["owner"],
            "environment": spec["to"],
        },
        "spec": {
            "artifactDigest": digest,
            "releaseProfile": spec["releaseProfile"],
            "strategy": profile["metadata"]["strategy"],
            "verification": str((ROOT / "promotion" / "verification" / "default.json").relative_to(ROOT)),
            "rollback": str((ROOT / "promotion" / "rollback" / "default.json").relative_to(ROOT)),
            "sourceRequest": args.request.as_posix(),
        },
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(desired, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(desired, indent=2))


if __name__ == "__main__":
    main()
