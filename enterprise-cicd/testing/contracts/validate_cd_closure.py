from __future__ import annotations

import json
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REPO = ROOT.parent
DIGEST_A = "sha256:" + "a" * 64
DIGEST_B = "sha256:" + "b" * 64


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def observation(digest: str, *, rollout: bool = True) -> dict:
    return {
        "apiVersion": "platform.verification/v1",
        "kind": "DeploymentObservation",
        "metadata": {"application": "go-smoke", "environment": "dev"},
        "spec": {
            "artifactRepository": "example.azurecr.io/go-smoke",
            "artifactDigest": digest,
            "fluxReady": True,
            "rolloutReady": rollout,
            "healthEndpointReady": True,
            "errorRatePercent": None,
            "p95LatencyMs": None,
            "observedAt": "2026-08-18T00:00:00Z",
            "source": "contract-test"
        }
    }


def run(*args: str, expected: int = 0) -> subprocess.CompletedProcess[str]:
    cp = subprocess.run(args, cwd=REPO, text=True, capture_output=True)
    if cp.returncode != expected:
        raise SystemExit(f"command failed ({cp.returncode}, expected {expected}): {' '.join(args)}\n{cp.stdout}\n{cp.stderr}")
    return cp


def main() -> None:
    policy = json.loads((ROOT / "promotion" / "verification" / "default.json").read_text(encoding="utf-8"))
    envs = policy["spec"]["environments"]
    assert set(envs) == {"dev", "test", "prod"}
    assert "error-rate" not in envs["dev"]["required"]
    assert "error-rate" in envs["prod"]["required"]
    assert policy["spec"]["onFailure"] == "rollback-pr"

    workflow = (REPO / ".github" / "workflows" / "reusable-release-verification-v1.yml").read_text(encoding="utf-8")
    for forbidden in ("kubectl apply", "helm upgrade", "helm install", "az aks get-credentials"):
        assert forbidden not in workflow, f"verification workflow must not directly deploy: {forbidden}"
    assert "gh pr create" in workflow
    assert "render_rollback.py" in workflow
    assert "record_approved_release.py" in workflow

    with tempfile.TemporaryDirectory() as tmp:
        tmpdir = Path(tmp)
        gitops = tmpdir / "gitops"
        shutil.copytree(ROOT / "gitops", gitops)

        pass_a = tmpdir / "pass-a.json"
        result_a = tmpdir / "result-a.json"
        write_json(pass_a, observation(DIGEST_A))
        run("python", "enterprise-cicd/promotion/verification/evaluate.py", "--observation", str(pass_a), "--output", str(result_a))
        run("python", "enterprise-cicd/promotion/record_approved_release.py", "--verification-result", str(result_a), "--gitops-root", str(gitops))

        pass_b = tmpdir / "pass-b.json"
        result_b = tmpdir / "result-b.json"
        write_json(pass_b, observation(DIGEST_B))
        run("python", "enterprise-cicd/promotion/verification/evaluate.py", "--observation", str(pass_b), "--output", str(result_b))
        run("python", "enterprise-cicd/promotion/record_approved_release.py", "--verification-result", str(result_b), "--gitops-root", str(gitops))

        ledger = json.loads((gitops / "environments" / "dev" / "apps" / "go-smoke" / "approved-release.json").read_text(encoding="utf-8"))
        assert ledger["spec"]["current"]["artifactDigest"] == DIGEST_B
        assert ledger["spec"]["previousApproved"]["artifactDigest"] == DIGEST_A

        failed = tmpdir / "failed.json"
        failed_result = tmpdir / "failed-result.json"
        write_json(failed, observation(DIGEST_B, rollout=False))
        run("python", "enterprise-cicd/promotion/verification/evaluate.py", "--observation", str(failed), "--output", str(failed_result), expected=2)
        run("python", "enterprise-cicd/promotion/render_rollback.py", "--application", "go-smoke", "--environment", "dev", "--verification-result", str(failed_result), "--gitops-root", str(gitops))

        overlay = (gitops / "environments" / "dev" / "apps" / "go-smoke" / "kustomization.yaml").read_text(encoding="utf-8")
        assert f"digest: {DIGEST_A}" in overlay
        rollback = json.loads((gitops / "environments" / "dev" / "apps" / "go-smoke" / "rollback-evidence.json").read_text(encoding="utf-8"))
        assert rollback["spec"]["failedDigest"] == DIGEST_B
        assert rollback["spec"]["rollbackDigest"] == DIGEST_A
        assert rollback["spec"]["rebuild"] is False

    print("CD CLOSURE VALIDATION: PASSED")
    print("pass -> approved ledger -> next pass -> previousApproved -> failed verification -> rollback previous digest")


if __name__ == "__main__":
    main()
