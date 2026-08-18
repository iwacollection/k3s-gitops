from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def load(path: Path):
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def safe_name(value: str) -> str:
    return re.sub(r"[^a-zA-Z0-9_.-]+", "-", value).strip("-")


def digest_inputs(profile_name: str, build_image: str, inputs: list[str], workspace: Path) -> str:
    h = hashlib.sha256()
    h.update(profile_name.encode())
    h.update(build_image.encode())
    h.update(platform.machine().encode())
    for item in inputs:
        path = workspace / item
        h.update(item.encode())
        if path.is_file():
            h.update(path.read_bytes())
        else:
            h.update(b"<missing>")
    return h.hexdigest()[:24]


def write_maven_settings(config_dir: Path, proxy_url: str) -> None:
    settings = f"""<settings xmlns=\"http://maven.apache.org/SETTINGS/1.0.0\"\n  xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"\n  xsi:schemaLocation=\"http://maven.apache.org/SETTINGS/1.0.0 https://maven.apache.org/xsd/settings-1.0.0.xsd\">\n  <mirrors>\n    <mirror>\n      <id>platform-proxy</id>\n      <name>Platform Maven Proxy</name>\n      <url>{proxy_url}</url>\n      <mirrorOf>*</mirrorOf>\n    </mirror>\n  </mirrors>\n</settings>\n"""
    (config_dir / "maven-settings.xml").write_text(settings, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Prepare cache/proxy settings for a platform CI build profile.")
    parser.add_argument("--application", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--env-file", required=True, type=Path)
    parser.add_argument("--config-dir", required=True, type=Path)
    parser.add_argument("--workspace", type=Path, default=Path("."))
    args = parser.parse_args()

    workspace = args.workspace.resolve()
    app = load(args.application)
    profile_name = app["spec"]["buildProfile"]
    profile_path = ROOT / "ci-catalog" / profile_name / "profile.json"
    profile = load(profile_path)
    spec = profile["spec"]

    cache_hash = digest_inputs(profile_name, spec["buildImage"], spec.get("cacheKeyInputs", []), workspace)
    configured_cache_root = os.getenv("PLATFORM_CACHE_ROOT", "").strip()
    cache_root = Path(configured_cache_root).resolve() if configured_cache_root else workspace / ".platform-cache"
    cache_dir = cache_root / safe_name(profile_name)
    cache_dir.mkdir(parents=True, exist_ok=True)
    args.config_dir.mkdir(parents=True, exist_ok=True)

    env: dict[str, str] = {}
    pre_commands: list[str] = []
    proxy = spec.get("dependencyProxy")

    if proxy == "maven":
        env["MAVEN_OPTS"] = "-Dmaven.repo.local=/platform-cache/m2"
        url = os.getenv("MAVEN_PROXY_URL", "").strip()
        if url:
            write_maven_settings(args.config_dir, url)
            env["MAVEN_ARGS"] = "-s /platform-config/maven-settings.xml"
    elif proxy == "pypi":
        env["UV_CACHE_DIR"] = "/platform-cache/uv"
        url = os.getenv("PYPI_INDEX_URL", "").strip()
        if url:
            env["UV_INDEX_URL"] = url
    elif proxy == "go":
        env.update({
            "GOMODCACHE": "/platform-cache/go/mod",
            "GOCACHE": "/platform-cache/go/build",
            "GOPATH": "/platform-cache/go/path",
        })
        url = os.getenv("GO_PROXY_URL", "").strip()
        if url:
            env["GOPROXY"] = url
    elif proxy == "cpp":
        env["CONAN_HOME"] = "/platform-cache/conan"
        env["CCACHE_DIR"] = "/platform-cache/ccache"
        url = os.getenv("CONAN_REMOTE_URL", "").strip()
        if url:
            pre_commands.append(f"conan remote add --force platform {json.dumps(url)}")

    args.env_file.parent.mkdir(parents=True, exist_ok=True)
    args.env_file.write_text("".join(f"{k}={v}\n" for k, v in sorted(env.items())), encoding="utf-8")

    result = {
        "profile": profile_name,
        "cacheKey": f"platform-ci-{safe_name(profile_name)}-{cache_hash}",
        "cacheDir": cache_dir.as_posix(),
        "envFile": args.env_file.as_posix(),
        "configDir": args.config_dir.as_posix(),
        "preCommand": " && ".join(pre_commands) if pre_commands else "true",
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
