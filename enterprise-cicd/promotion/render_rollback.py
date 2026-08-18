from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> None:
    parser = argparse.ArgumentParser(description="Render a governed rollback to the previous approved digest.")
    parser.add_argument("--application", required=True)
    parser.add_argument("--environment", required=True, choices=["dev", "test", "prod"])
    parser.add_argument("--verification-result", required=True, type=Path)
    parser.add_argument("--gitops-root", type=Path, default=ROOT / "gitops")
    args = parser.parse_args()

    result = load(args.verification_result)
    if result.get("kind") != "VerificationResult" or result["spec"].get("status") != "failed":
        raise SystemExit("rollback requires a failed VerificationResult")
    if result["metadata"].get("application") != args.application or result["metadata"].get("environment") != args.environment:
        raise SystemExit("verification result does not match rollback target")

    policy = load(ROOT / "promotion" / "rollback" / "default.json")
    if policy["spec"].get("target") != "previous-approved-digest" or policy["spec"].get("rebuildForbidden") is not True:
        raise SystemExit("rollback policy is not safe")

    app_dir = args.gitops_root / "environments" / args.environment / "apps" / args.application
    ledger_path = app_dir / "approved-release.json"
    if not ledger_path.is_file():
        raise SystemExit("no approved release ledger exists; automatic rollback is not safe")

    ledger = load(ledger_path)
    previous = ledger.get("spec", {}).get("previousApproved")
    if not previous:
        raise SystemExit("no previous approved release exists; automatic rollback is not safe")

    repository = previous["artifactRepository"]
    digest = previous["artifactDigest"]
    relative_base = f"../../../../apps/{args.application}/base"
    overlay = "\n".join([
        "apiVersion: kustomize.config.k8s.io/v1beta1",
        "kind: Kustomization",
        f"namespace: cicd-{args.environment}",
        "resources:",
        f"  - {relative_base}",
        "images:",
        f"  - name: platform.local/{args.application}",
        f"    newName: {repository}",
        f"    digest: {digest}",
        "",
    ])
    (app_dir / "kustomization.yaml").write_text(overlay, encoding="utf-8")

    evidence = {
        "apiVersion": "platform.rollback/v1",
        "kind": "RollbackEvidence",
        "metadata": {"application": args.application, "environment": args.environment},
        "spec": {
            "failedDigest": result["spec"]["artifactDigest"],
            "rollbackRepository": repository,
            "rollbackDigest": digest,
            "sourceVerificationResult": args.verification_result.as_posix(),
            "reason": "verification-gate-failed",
            "rebuild": False,
            "postRollbackVerificationRequired": policy["spec"]["postRollbackVerificationRequired"],
        },
    }
    evidence_path = app_dir / "rollback-evidence.json"
    evidence_path.write_text(json.dumps(evidence, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"application": args.application, "environment": args.environment, "rollbackDigest": digest, "rollbackEvidence": evidence_path.as_posix()}, indent=2))


if __name__ == "__main__":
    main()
