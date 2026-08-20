from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> None:
    parser = argparse.ArgumentParser(description="Render a governed rollback to the last approved digest before the failed candidate.")
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
    baseline = ledger.get("spec", {}).get("current")
    if not baseline:
        raise SystemExit("no current approved release exists; automatic rollback is not safe")

    failed_digest = result["spec"]["artifactDigest"]
    repository = baseline["artifactRepository"]
    digest = baseline["artifactDigest"]
    if digest == failed_digest:
        raise SystemExit("failed candidate already equals current approved digest; automatic rollback target is ambiguous")

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
            "failedDigest": failed_digest,
            "rollbackRepository": repository,
            "rollbackDigest": digest,
            "rollbackBaseline": "last-approved-before-candidate",
            "sourceVerificationResult": args.verification_result.as_posix(),
            "sourceApprovedRelease": ledger_path.as_posix(),
            "reason": "verification-gate-failed",
            "rebuild": False,
            "postRollbackVerificationRequired": policy["spec"]["postRollbackVerificationRequired"],
        },
    }
    evidence_path = app_dir / "rollback-evidence.json"
    evidence_path.write_text(json.dumps(evidence, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"application": args.application, "environment": args.environment, "failedDigest": failed_digest, "rollbackDigest": digest, "rollbackEvidence": evidence_path.as_posix()}, indent=2))


if __name__ == "__main__":
    main()
