from __future__ import annotations

import json
import os
import re
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
    digest_binding_path = ROOT / "build-images" / "digests" / "active.json"
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

    if not digest_binding_path.is_file():
        fail(errors, "active platform build-image digest binding is missing")
        bound_images = {}
    else:
        digest_binding = load(digest_binding_path)
        if digest_binding.get("apiVersion") != "platform.ci/v1" or digest_binding.get("kind") != "BuildImageDigestBinding":
            fail(errors, "invalid active build-image digest binding envelope")
        binding_spec = digest_binding.get("spec") or {}
        bound_images = binding_spec.get("images") or {}
        if not binding_spec.get("acrName"):
            fail(errors, "active build-image digest binding must declare acrName")
        if binding_spec.get("promotionByDigest") is not True:
            fail(errors, "platform build-image promotion must remain digest-based")
        if binding_spec.get("mutableTagExecutionAllowed") is not False:
            fail(errors, "platform build execution must never follow mutable tags")
        if set(bound_images) != set(images):
            fail(
                errors,
                "active build-image digest binding must cover the exact registered image set: "
                f"missing={sorted(set(images) - set(bound_images))} unexpected={sorted(set(bound_images) - set(images))}",
            )
        for name, digest in bound_images.items():
            if not isinstance(digest, str) or not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
                fail(errors, f"invalid active digest binding for {name}: {digest!r}")

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
        if image not in bound_images:
            fail(errors, f"profile build image has no active immutable digest binding: {profile_path}: {image}")
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
        "activeDigest",
        "buildImageDigest",
        'ROOT / "build-images" / "digests" / "active.json"',
        "json.dumps(profile, sort_keys=True",
        "json.dumps(image_metadata, sort_keys=True",
        "cacheRestorePrefix",
        'cache_prefix = f"platform-ci-{safe_name(profile_name)}-"',
    ):
        require_text(errors, prepare_text, required, f"build cache helper missing toolchain/digest/profile isolation control: {required}")

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
                    ["python", str(resolver_path), "--application", str(smoke_application), "--output", str(resolved_path)],
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
                expected_builder_digest = bound_images.get(resolved.get("buildImage"))
                if prepared.get("buildImageDigest") != expected_builder_digest:
                    fail(
                        errors,
                        "prepared build environment did not inherit the active immutable builder digest: "
                        f"expected={expected_builder_digest} actual={prepared.get('buildImageDigest')}",
                    )
            except subprocess.CalledProcessError as exc:
                fail(errors, f"smoke application resolver/cache contract failed: stdout={exc.stdout} stderr={exc.stderr}")

    reusable_path = REPO_ROOT / ".github" / "workflows" / "reusable-application-ci-v2.yml"
    matrix_path = REPO_ROOT / ".github" / "workflows" / "reusable-application-ci-matrix-v2.yml"
    legacy_path = REPO_ROOT / ".github" / "workflows" / "enterprise-ci-reusable.yml"
    if not reusable_path.is_file():
        fail(errors, "canonical callable reusable application CI v2 workflow is missing")
    else:
        reusable = reusable_path.read_text(encoding="utf-8")
        for job in ("resolve", "source-scan", "build-test", "image-build", "image-scan", "sbom", "sign", "release-evidence"):
            require_text(errors, reusable, f"  {job}:\n", f"reusable CI v2 missing DAG job: {job}")

        required_edges = {
            "source-scan": "needs: resolve",
            "build-test": "needs: resolve",
            "image-build": "needs: [resolve, source-scan, build-test]",
            "image-scan": "needs: [resolve, image-build]",
            "sbom": "needs: [resolve, image-build]",
            "sign": "needs: [resolve, image-build, image-scan, sbom]",
            "release-evidence": "needs: [resolve, build-test, image-build, image-scan, sbom, sign]",
        }
        for job, edge in required_edges.items():
            require_text(errors, reusable, edge, f"reusable CI v2 missing governed needs edge for {job}: {edge}")

        for forbidden in ("kubectl apply", "helm upgrade", "helm install", "az aks get-credentials", "terraform apply"):
            if forbidden in reusable:
                fail(errors, f"application CI v2 contains forbidden deployment command: {forbidden}")

        for required in (
            "actions/upload-artifact@v4",
            "actions/download-artifact@v5",
            "--sbom=true",
            "--provenance=mode=max",
            "cosign sign --yes",
            "GITHUB_SHA",
            "github_environment:",
            "environment: ${{ inputs.github_environment }}",
            "environment-bindings.json",
            "source_path: ${{ steps.resolve.outputs.source_path }}",
            "scan-ref: ${{ needs.resolve.outputs.source_path }}",
            "build_image_digest: ${{ steps.build-image.outputs.digest }}",
            "cache_restore_prefix=$(jq -r .cacheRestorePrefix",
            "${{ steps.prepare.outputs.cache_restore_prefix }}",
            "enterprise-cicd/build-images/digests/active.json",
            'test "$LIVE_DIGEST" = "$COMMITTED_DIGEST"',
            'image_ref=$LOGIN_SERVER/build/$NAME@$COMMITTED_DIGEST',
            'docker pull "$IMAGE_REF"',
            'tar --exclude=',
            "/tmp/app-build-context",
            'builder:{image:$buildImage,digest:$buildImageDigest}',
        ):
            require_text(errors, reusable, required, f"reusable CI v2 missing required supply-chain/source/cache/digest/OIDC control: {required}")
        if "${{ runner.os }}-${{ runner.arch }}-platform-ci-\n" in reusable:
            fail(errors, "dependency cache restore fallback must not be global across build profiles")
        if 'docker pull "$LOGIN_SERVER/build/' in reusable:
            fail(errors, "platform build execution must use resolved immutable IMAGE_REF rather than a tag expression")
        for forbidden_secret in ("AZURE_CLIENT_ID", "AZURE_TENANT_ID", "AZURE_SUBSCRIPTION_ID"):
            if f"secrets:\n      {forbidden_secret}:" in reusable:
                fail(errors, f"canonical reusable CI v2 must not accept caller-supplied Azure identity secret {forbidden_secret}")

    if not matrix_path.is_file():
        fail(errors, "canonical matrix reusable CI v2 orchestrator is missing")
    else:
        matrix = matrix_path.read_text(encoding="utf-8")
        for required in (
            "strategy:",
            "matrix:",
            "needs: define-matrix",
            "uses: ./.github/workflows/reusable-application-ci-v2.yml",
            "needs: [define-matrix, application-ci]",
            "fail-fast: false",
            "max-parallel: 4",
            "length > 20",
            "github_environment: ${{ inputs.github_environment }}",
            "environmentMatrixAllowed",
        ):
            if required == "environmentMatrixAllowed":
                continue
            require_text(errors, matrix, required, f"matrix v2 orchestration missing required control: {required}")
        for forbidden_secret in ("AZURE_CLIENT_ID", "AZURE_TENANT_ID", "AZURE_SUBSCRIPTION_ID"):
            if forbidden_secret in matrix:
                fail(errors, f"matrix v2 must not accept caller-supplied Azure identity secret {forbidden_secret}")

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
    expected_single = ".github/workflows/reusable-application-ci-v2.yml"
    expected_matrix = ".github/workflows/reusable-application-ci-matrix-v2.yml"
    if policy.get("singleApplicationWorkflow") != expected_single:
        fail(errors, f"canonical single-application reusable workflow must be {expected_single}")
    if policy.get("matrixWorkflow") != expected_matrix:
        fail(errors, f"canonical matrix reusable workflow must be {expected_matrix}")
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
    if policy.get("azureAuthentication") != "platform-environment-oidc-binding":
        fail(errors, "canonical CI authentication must come from platform environment OIDC bindings")
    if policy.get("callerSuppliedAzureIdentitySecretsAllowed") is not False:
        fail(errors, "callers must not supply Azure identity secrets to canonical CI")
    if policy.get("matrixMaxApplications") != 20 or policy.get("matrixMaxParallel") != 4:
        fail(errors, "matrix v2 governed capacity limits changed")

    caller_example = (ROOT / "github-actions" / "policies" / "application-caller.example.yml").read_text(encoding="utf-8")
    require_text(errors, caller_example, "reusable-application-ci-v2.yml@PLATFORM_RELEASE_REF", "caller example must use canonical v2 and pin an explicit platform release ref")
    if "reusable-application-ci-v2.yml@main" in caller_example:
        fail(errors, "production caller example must not follow @main")
    for forbidden_secret in ("AZURE_CLIENT_ID", "AZURE_TENANT_ID", "AZURE_SUBSCRIPTION_ID"):
        if forbidden_secret in caller_example:
            fail(errors, f"canonical caller example must not pass Azure identity secret {forbidden_secret}")

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
    print(f"active immutable build-image digests: {len(bound_images)}")
    print(f"validated profiles: {len(profiles)}")
    print("canonical reusable: v2 single application + v2 matrix")
    print("lifecycle: prepare -> verify -> package")
    print("orchestration: matrix outside; needs DAG inside reusable workflow")
    print("consumption: thin callers; platform workflow pinned by immutable release ref")
    print("authentication: platform environment OIDC binding; no caller-supplied Azure identity secrets")
    print("security: source + container controls required before signing")
    print("monorepo: source scan/build/package/container context isolated by Application sourcePath")
    print("builder: committed sha256 digest verified against live ACR tag and recorded in release evidence")
    print("cache: profile + builder digest + toolchain metadata + lock inputs; fallback cannot cross build profiles")
    print("legacy arbitrary-command reusable entrypoint: fail-closed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
