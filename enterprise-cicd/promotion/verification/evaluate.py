from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> None:
    parser = argparse.ArgumentParser(description="Evaluate deployment observation against environment policy.")
    parser.add_argument("--observation", required=True, type=Path)
    parser.add_argument("--policy", type=Path, default=Path(__file__).with_name("default.json"))
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    observation = load(args.observation)
    policy = load(args.policy)
    metadata = observation["metadata"]
    spec = observation["spec"]
    environment = metadata["environment"]
    env_policy = policy["spec"]["environments"][environment]

    checks: list[dict[str, object]] = []

    def check(name: str, passed: bool, actual=None, expected=None) -> None:
        checks.append({"name": name, "passed": bool(passed), "actual": actual, "expected": expected})

    required = set(env_policy["required"])
    if "flux-ready" in required:
        check("flux-ready", spec["fluxReady"] is True, spec["fluxReady"], True)
    if "rollout-ready" in required:
        check("rollout-ready", spec["rolloutReady"] is True, spec["rolloutReady"], True)
    if "health-endpoint" in required:
        check("health-endpoint", spec["healthEndpointReady"] is True, spec["healthEndpointReady"], True)

    thresholds = env_policy["thresholds"]
    if "error-rate" in required:
        limit = thresholds["errorRatePercent"]
        actual = spec.get("errorRatePercent")
        check("error-rate", actual is not None and actual <= limit, actual, f"<= {limit}")
    if "latency" in required:
        limit = thresholds["p95LatencyMs"]
        actual = spec.get("p95LatencyMs")
        check("latency", actual is not None and actual <= limit, actual, f"<= {limit}")

    passed = all(item["passed"] for item in checks)
    result = {
        "apiVersion": "platform.verification/v1",
        "kind": "VerificationResult",
        "metadata": {
            "application": metadata["application"],
            "environment": environment,
        },
        "spec": {
            "artifactRepository": spec["artifactRepository"],
            "artifactDigest": spec["artifactDigest"],
            "status": "passed" if passed else "failed",
            "evaluatedAt": datetime.now(timezone.utc).isoformat(),
            "observation": args.observation.as_posix(),
            "checks": checks,
            "onFailure": policy["spec"]["onFailure"],
        },
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if passed else 2)


if __name__ == "__main__":
    main()
