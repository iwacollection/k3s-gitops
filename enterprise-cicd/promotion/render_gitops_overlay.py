from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DIGEST_RE = re.compile(r"^sha256:[a-f0-9]{64}$")
VALID_ENVIRONMENTS = {"dev", "test", "prod"}


def load_json(path: Path):
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def fail(message: str) -> None:
    raise SystemExit(message)


def write_environment_root(environment_dir: Path) -> None:
    app_resources = []
    apps_dir = environment_dir / "apps"
    if apps_dir.is_dir():
        for child in sorted(apps_dir.iterdir()):
            if child.is_dir() and (child / "kustomization.yaml").is_file():
                app_resources.append(f"./apps/{child.name}")

    lines = [
        "apiVersion: kustomize.config.k8s.io/v1beta1",
        "kind: Kustomization",
        "resources:",
        "  - namespace.yaml",
    ]
    lines.extend(f"  - {resource}" for resource in app_resources)
    (environment_dir / "kustomization.yaml").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Render a governed release request into a Flux/Kustomize environment overlay.")
    parser.add_argument("--request", required=True, type=Path)
    parser.add_argument("--gitops-root", type=Path, default=ROOT / "gitops")
    args = parser.parse_args()

    request = load_json(args.request)
    if request.get("apiVersion") != "platform.release/v1" or request.get("kind") != "Release":
        fail("invalid release request")

    metadata = request.get("metadata", {})
    spec = request.get("spec", {})
    application = metadata.get("application", "")
    owner = metadata.get("owner", "")
    source_environment = spec.get("from", "")
    target_environment = spec.get("to", "")
    repository = spec.get("artifactRepository", "")
    digest = spec.get("artifactDigest", "")
    release_profile = spec.get("releaseProfile", "")

    if not application or not owner:
        fail("release metadata.application and metadata.owner are required")
    if target_environment not in VALID_ENVIRONMENTS:
        fail(f"unsupported target environment: {target_environment}")
    if not repository or "@" in repository:
        fail("artifactRepository must be a repository without a digest")
    if not DIGEST_RE.fullmatch(digest):
        fail("release must reference an immutable sha256 digest")

    promotion = load_json(ROOT / "promotion" / "policies" / "default.json")
    transition = f"{source_environment}->{target_environment}"
    if transition not in promotion["spec"]["allowedTransitions"]:
        fail(f"promotion transition is not allowed: {transition}")

    profile_path = ROOT / "release-catalog" / release_profile / "profile.json"
    if not profile_path.is_file():
        fail(f"unknown release profile: {release_profile}")
    profile = load_json(profile_path)
    strategy = profile.get("metadata", {}).get("strategy", "")
    execution = profile.get("spec", {}).get("execution", {})
    if execution.get("ready") is not True:
        controller = execution.get("requiresController", "unspecified")
        fail(
            f"release profile {release_profile} is cataloged but not executable yet; "
            f"strategy={strategy}, required-controller={controller}"
        )

    app_base = args.gitops_root / "apps" / application / "base"
    if not (app_base / "kustomization.yaml").is_file():
        fail(f"application has no governed GitOps base: {application}")

    environment_dir = args.gitops_root / "environments" / target_environment
    if not environment_dir.is_dir():
        fail(f"GitOps environment directory does not exist: {target_environment}")

    overlay_dir = environment_dir / "apps" / application
    overlay_dir.mkdir(parents=True, exist_ok=True)

    namespace = f"cicd-{target_environment}"
    relative_base = f"../../../../apps/{application}/base"
    overlay = "\n".join(
        [
            "apiVersion: kustomize.config.k8s.io/v1beta1",
            "kind: Kustomization",
            f"namespace: {namespace}",
            "resources:",
            f"  - {relative_base}",
            "images:",
            f"  - name: platform.local/{application}",
            f"    newName: {repository}",
            f"    digest: {digest}",
            "",
        ]
    )
    (overlay_dir / "kustomization.yaml").write_text(overlay, encoding="utf-8")

    evidence = {
        "apiVersion": "platform.gitops/v1",
        "kind": "PromotionEvidence",
        "metadata": {
            "application": application,
            "owner": owner,
            "environment": target_environment,
        },
        "spec": {
            "artifactRepository": repository,
            "artifactDigest": digest,
            "from": source_environment,
            "to": target_environment,
            "releaseProfile": release_profile,
            "strategy": strategy,
            "executionEngine": execution.get("engine"),
            "changeReason": spec.get("changeReason", ""),
            "sourceRequest": args.request.as_posix(),
        },
    }
    (overlay_dir / "release-evidence.json").write_text(json.dumps(evidence, indent=2) + "\n", encoding="utf-8")

    write_environment_root(environment_dir)

    print(json.dumps({
        "environment": target_environment,
        "application": application,
        "overlay": str(overlay_dir / "kustomization.yaml"),
        "digest": digest,
        "releaseProfile": release_profile,
        "strategy": strategy,
        "executionEngine": execution.get("engine"),
    }, indent=2))


if __name__ == "__main__":
    main()
