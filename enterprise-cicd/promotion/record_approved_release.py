from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> None:
    parser = argparse.ArgumentParser(description="Record a passed verification as the approved release for an environment.")
    parser.add_argument("--verification-result", required=True, type=Path)
    parser.add_argument("--gitops-root", type=Path, default=ROOT / "gitops")
    args = parser.parse_args()

    result = load(args.verification_result)
    if result.get("kind") != "VerificationResult" or result["spec"].get("status") != "passed":
        raise SystemExit("only passed verification results may become approved releases")

    metadata = result["metadata"]
    spec = result["spec"]
    app = metadata["application"]
    environment = metadata["environment"]
    status_path = args.gitops_root / "environments" / environment / "apps" / app / "approved-release.json"
    status_path.parent.mkdir(parents=True, exist_ok=True)

    old = load(status_path) if status_path.is_file() else None
    previous_current = old.get("spec", {}).get("current") if old else None
    history = list(old.get("spec", {}).get("history", [])) if old else []

    current = {
        "artifactRepository": spec["artifactRepository"],
        "artifactDigest": spec["artifactDigest"],
        "verifiedAt": spec["evaluatedAt"],
        "verificationResult": args.verification_result.as_posix(),
    }
    if previous_current and previous_current.get("artifactDigest") != current["artifactDigest"]:
        history.insert(0, previous_current)
    history = history[:20]

    ledger = {
        "apiVersion": "platform.release/v1",
        "kind": "ApprovedRelease",
        "metadata": {"application": app, "environment": environment},
        "spec": {
            "current": current,
            "previousApproved": history[0] if history else None,
            "history": history,
        },
    }
    status_path.write_text(json.dumps(ledger, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"approvedRelease": status_path.as_posix(), "currentDigest": current["artifactDigest"], "previousApprovedDigest": (history[0]["artifactDigest"] if history else None)}, indent=2))


if __name__ == "__main__":
    main()
