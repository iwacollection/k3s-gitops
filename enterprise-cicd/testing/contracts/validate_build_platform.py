from __future__ import annotations

import json
import os
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REPO_ROOT = ROOT.parent


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def require_text(errors: list[str], text: str, token: str, message: str) -> None:
    if token not in text:
        fail(errors, message)


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
        commands = spec.get("commands", {})
        for phase in ("prepare", "verify", "package"):
            if not commands.get(phase):
                fail(errors, f"profile must define {phase} command: {profile_path}")
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
    if dependency["rules"].get("cacheSharedByLockHashOnly") is not True:
        fail(errors, "dependency cache sharing must remain governed by build profile/toolchain and lock inputs")

    resolver_path = ROOT / "ci-scripts" / "common" / "resolve_application.py"
    prepare_path = ROOT / "ci-scripts" / "common" / "prepare_build_env.py"
    resolver_text = resolver_path.read_text(encoding="utf-8")
    prepare_text = prepare_path.read_text(encoding="utf-8")
    for required in (
        "safe_relative_path",
        "application sourcePath does not exist",
        "artifact dockerfile escapes application sourcePath",
        "unsafe artifact repository name",
    ):
        require_text(errors, resolver_text, required, f"application resolver missing source-boundary control: {required}")
    for required in (
        "image_metadata",
        "json.dumps(profile, sort_keys=True",
        "json.dumps(image_metadata, sort_keys=True",
        'cacheRestorePrefix',
        'cache_prefix = f"platform-ci-{safe_name(profile_name)}-"',
    ):
        require_text(errors, prepare_text, required, f"build cache helper missing toolchain/profile isolation control: {required}")

    smoke_application = ROOT / "application-definitions" / "platform-smoke-api.json"
    if smoke_application.is_file():
        with tempfile.TemporaryDirectory(prefix="build-platform-contract-") as tmp:
            tmpdir = Path(tmp)
            resolved_path = tmpdir / "resolved.json"
            prepared_path = tmpdir / "prepared.json"
            env_path = tmpdir / "build.env"
            config_dir = tmpdir / "config"
            cache_root = tmpdir / "cache"
            try:
                subprocess.run(
                    [
                        "python",
                        str(resolver_path),
                        "--application",
                        str(smoke_application),
                        "--output",
                        str(resolved_path),
                    ],
                    cwd=REPO_ROOT,
                    check=True,
                    capture_output=True,
                    text=True,
                )
                resolved = load(resolved_path)
                if resolved.get("sourcePath") != "enterprise-cicd/testing/e2e/platform-smoke-api":
                    fail(errors, f"smoke Application sourcePath resolved incorrectly: {resolved.get('sourcePath')}")
                source_dir = REPO_ROOT / resolved["sourcePath"]
                if not (source_dir / resolved["dockerfile"]).is_file():
                    fail(errors, "resolved container Dockerfile is not inside the Application sourcePath")

                env = dict(os.environ)
                env["PLATFORM_CACHE_ROOT"] = str(cache_root)
                subprocess.run(
                    [
                        "python",
                        str(prepare_path),
                        "--application",
                        str(smoke_application),
                        "--workspace",
                        str(source_dir),
                        "--output",
                        str(prepared_path),
                        "--env-file",
                        str(env_path),
                        "--config-dir",
                        str(config_dir),
                    ],
                    cwd=REPO_ROOT,
                    env=env,
                    check=True,
                    capture_output=True,
                    text=True,
                )
                prepared = load(prepared_path)
                if prepared.get("cacheRestorePrefix") != "platform-ci-python-python-uv-v1-":
                    fail(errors, f"cache restore prefix is not build-profile scoped: {prepared.get('cacheRestorePrefix')}")
                if not str(prepared.get("cacheKey", "")).startswith(prepared.get("cacheRestorePrefix", "__missing__")):
                    fail(errors, "exact cache key must be nested under its profile-scoped restore prefix")
            except subprocess.CalledProcessError as exc:
                fail(errors, f"smoke application resolver/cache contract failed: stdout={exc.stdout} stderr={exc.stderr}")

    reusable_path = REPO_ROOT / ".github" / "workflows" / "reusable-application-ci-v1.yml"
    matrix_path = REPO_ROOT / ".github" / "workflows" / "reusable-application-ci-matrix-v1.yml"
    legacy_path = REPO_ROOT / ".github" / "workflows" / "enterprise-ci-reusable.yml"
    if not reusable_path.is_file():
        fail(errors, "callable reusable application CI workflow is missing")
    else:
        reusable = reusable_path.read_text(encoding="utf-8")
        for job in ("resolve", "source-scan", "build-test", "image-build", "image-scan", "sbom", "sign", "release-evidence"):
            require_text(errors, reusable, f"  {job}:\n", f"reusable CI missing DAG job: {job}")

        required_edges = {
            "source-scan": "needs: resolve",
            "build-test": "needs: resolve",
            "image-build": "needs: [resolve, source-scan, build-test]",
            "image-scan": "needs: [resolve, image-build]",
            "sbom": "needs: [resolve, image-build]",
            "sign": "needs: [resolve, image-build, image-scan, sbom]",
            "release-evidence": "needs: [resolve, image-build, image-scan, sbom, sign]",
        }
        for job, edge in required_edges.items():
            require_text(errors, reusable, edge, f"reusable CI missing governed needs edge for {job}: {edge}")

        for forbidden in ("kubectl apply", "helm upgrade", "helm install", "az aks get-credentials", "terraform apply"):
            if forbidden in reusable:
                fail(errors, f"application CI contains forbidden deployment command: {forbidden}")

        for required in (
            "actions/upload-artifact@v4",
            "actions/download-artifact@v5",
            "--sbom=true",
            "--provenance=mode=max",
            "cosign sign --yes",
            "GITHUB_SHA",
            "source_path: ${{ steps.resolve.outputs.source_path }}",
            "scan-ref: ${{ needs.resolve.outputs.source_path }}",
            "--workspace '${{ needs.resolve.outputs.source_path }}'",
            "cache_restore_prefix=$(jq -r .cacheRestorePrefix",
            "${{ steps.prepare.outputs.cache_restore_prefix }}",
            '-v "$source_dir:/workspace"',
            'tar -C "$source_dir" -czf /tmp/build-workspace.tgz .',
            "mkdir -p /tmp/application-source",
            '"$source_dir"',
        ):
            require_text(errors, reusable, required, f"reusable CI missing required supply-chain/source/cache control: {required}")
        if "${{ runner.os }}-${{ runner.arch }}-platform-ci-\n" in reusable:
            fail(errors, "dependency cache restore fallback must not be global across build profiles")

    if not matrix_path.is_file():
        fail(errors, "matrix reusable CI orchestrator is missing")
    else:
        matrix = matrix_path.read_text(encoding="utf-8")
        for required in (
            "strategy:",
            "matrix:",
            "needs: define-matrix",
            "uses: ./.github/workflows/reusable-application-ci-v1.yml",
            "needs: [define-matrix, application-ci]",
            "fail-fast: false",
            "max-parallel: 4",
        ):
            require_text(errors, matrix, required, f"matrix orchestration missing required control: {required}")

    if not legacy_path.is_file():
        fail(errors, "deprecated enterprise CI compatibility workflow is missing")
    else:
        legacy = legacy_path.read_text(encoding="utf-8")
        require_text(errors, legacy, "enterprise-ci-reusable-deprecated", "legacy CI entrypoint must remain visibly deprecated")
        require_text(errors, legacy, "Reject deprecated arbitrary-command CI entrypoint", "legacy CI must fail closed")
        require_text(errors, legacy, "exit 1", "legacy arbitrary-command workflow must reject execution")
        if "${{ inputs.build_command }}" in legacy:
            fail(errors, "legacy caller-supplied build_command must never be executed")

    consumption_policy = load(ROOT / "github-actions" / "policies" / "reusable-workflow-consumption.json")
    policy = consumption_policy["spec"]
    if policy.get("platformOwnsDAG") is not True:
        fail(errors, "platform must own the reusable workflow DAG")
    if policy.get("callerOwnsBusinessTriggers") is not True:
        fail(errors, "application caller should own business trigger selection")
    if policy.get("mainBranchAllowedForProduction") is not False:
        fail(errors, "production reusable workflow calls must not follow main")
    if policy.get("environmentMatrixAllowed") is not False:
        fail(errors, "DEV/TEST/PROD promotion must not be modeled as a matrix")
    if policy.get("directProductionDeploymentFromCI") is not False:
        fail(errors, "CI must not directly deploy production")

    caller_example = (ROOT / "github-actions" / "policies" / "application-caller.example.yml").read_text(encoding="utf-8")
    require_text(errors, caller_example, "reusable-application-ci-v1.yml@PLATFORM_RELEASE_REF", "caller example must pin an explicit platform release ref")
    if "reusable-application-ci-v1.yml@main" in caller_example:
        fail(errors, "production caller example must not follow @main")

    stale_copy = ROOT / "github-actions" / "reusable" / "application-ci.yml"
    if stale_copy.exists():
        fail(errors, "stale duplicate reusable workflow copy must not exist outside .github/workflows")

    if errors:
        print("BUILD PLATFORM VALIDATION: FAILED")
        for error in errors:
            print(f"- {error}")
        return 1

    print("BUILD PLATFORM VALIDATION: PASSED")
    print(f"registered images: {len(images)}")
    print(f"validated profiles: {len(profiles)}")
    print("lifecycle: prepare -> verify -> package")
    print("orchestration: matrix outside; needs DAG inside reusable workflow")
    print("consumption: thin callers; platform workflow pinned by immutable release ref")
    print("security: source + container controls required before signing")
    print("monorepo: source scan/build/package/container context isolated by Application sourcePath")
    print("cache: profile + toolchain metadata + lock inputs; fallback cannot cross build profiles")
    print("legacy arbitrary-command reusable entrypoint: fail-closed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
