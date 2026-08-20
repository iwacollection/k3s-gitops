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
DIGEST_C = "sha256:" + "c" * 64
REPOSITORY = "example.azurecr.io/go-smoke"


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def observation(digest: str, *, rollout: bool = True, artifact_identity: bool = True) -> dict:
    return {
        "apiVersion": "platform.verification/v1",
        "kind": "DeploymentObservation",
        "metadata": {"application": "go-smoke", "environment": "dev"},
        "spec": {
            "artifactRepository": REPOSITORY,
            "artifactDigest": digest,
            "fluxReady": True,
            "artifactIdentityReady": artifact_identity,
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
    assert "artifact-identity" in envs["dev"]["required"]
    assert "error-rate" not in envs["dev"]["required"]
    assert "error-rate" in envs["prod"]["required"]
    assert policy["spec"]["onFailure"] == "rollback-pr"

    verification_workflow = (REPO / ".github" / "workflows" / "reusable-release-verification-v1.yml").read_text(encoding="utf-8")
    observer_workflow = (REPO / ".github" / "workflows" / "reusable-aks-observation-v1.yml").read_text(encoding="utf-8")
    for text in (verification_workflow, observer_workflow):
        for forbidden in ("kubectl apply", "helm upgrade", "helm install"):
            assert forbidden not in text, f"CD read/verification workflow must not directly deploy: {forbidden}"
    assert "admin: 'false'" in observer_workflow
    assert "azure/aks-set-context@v5" in observer_workflow
    assert "azure/use-kubelogin@v1.2" in observer_workflow
    assert "gh pr create" in verification_workflow
    assert "render_rollback.py" in verification_workflow
    assert "record_approved_release.py" in verification_workflow

    with tempfile.TemporaryDirectory() as tmp:
        tmpdir = Path(tmp)
        gitops = tmpdir / "gitops"
        shutil.copytree(ROOT / "gitops", gitops)

        flux = tmpdir / "flux.json"
        deployment = tmpdir / "deployment.json"
        endpoints = tmpdir / "endpoints.json"
        collected = tmpdir / "collected.json"
        write_json(flux, {"complianceState": "Compliant"})
        write_json(deployment, {
            "metadata": {"generation": 3},
            "spec": {"replicas": 1, "template": {"spec": {"containers": [{"name": "app", "image": f"{REPOSITORY}@{DIGEST_A}"}]}}},
            "status": {"observedGeneration": 3, "availableReplicas": 1, "readyReplicas": 1, "updatedReplicas": 1, "conditions": [{"type": "Available", "status": "True"}]}
        })
        write_json(endpoints, {"items": [{"endpoints": [{"addresses": ["10.0.0.1"], "conditions": {"ready": True}}]}]})
        run(
            "python", "enterprise-cicd/promotion/verification/collect_aks_observation.py",
            "--application", "go-smoke", "--environment", "dev",
            "--artifact-repository", REPOSITORY, "--artifact-digest", DIGEST_A,
            "--flux-json", str(flux), "--deployment-json", str(deployment),
            "--endpoints-json", str(endpoints), "--output", str(collected)
        )
        normalized = json.loads(collected.read_text(encoding="utf-8"))
        assert normalized["spec"]["fluxReady"] is True
        assert normalized["spec"]["artifactIdentityReady"] is True
        assert normalized["spec"]["rolloutReady"] is True
        assert normalized["spec"]["healthEndpointReady"] is True

        identity_fail = tmpdir / "identity-fail.json"
        identity_fail_result = tmpdir / "identity-fail-result.json"
        write_json(identity_fail, observation(DIGEST_A, artifact_identity=False))
        run("python", "enterprise-cicd/promotion/verification/evaluate.py", "--observation", str(identity_fail), "--output", str(identity_fail_result), expected=2)

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

        failed = tmpdir / "failed-c.json"
        failed_result = tmpdir / "failed-c-result.json"
        write_json(failed, observation(DIGEST_C, rollout=False))
        run("python", "enterprise-cicd/promotion/verification/evaluate.py", "--observation", str(failed), "--output", str(failed_result), expected=2)
        run("python", "enterprise-cicd/promotion/render_rollback.py", "--application", "go-smoke", "--environment", "dev", "--verification-result", str(failed_result), "--gitops-root", str(gitops))

        overlay = (gitops / "environments" / "dev" / "apps" / "go-smoke" / "kustomization.yaml").read_text(encoding="utf-8")
        assert f"digest: {DIGEST_B}" in overlay
        rollback = json.loads((gitops / "environments" / "dev" / "apps" / "go-smoke" / "rollback-evidence.json").read_text(encoding="utf-8"))
        assert rollback["spec"]["failedDigest"] == DIGEST_C
        assert rollback["spec"]["rollbackDigest"] == DIGEST_B
        assert rollback["spec"]["rollbackBaseline"] == "last-approved-before-candidate"
        assert rollback["spec"]["rebuild"] is False

    print("CD CLOSURE VALIDATION: PASSED")
    print("read-only observation -> artifact identity -> verification -> approved ledger -> failed candidate -> rollback last approved")


if __name__ == "__main__":
    main()
