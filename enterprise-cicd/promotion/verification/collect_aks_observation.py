from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def flux_ready(payload: dict) -> bool:
    state = payload.get("complianceState") or payload.get("properties", {}).get("complianceState")
    return state == "Compliant"


def deployment_ready(payload: dict) -> bool:
    metadata = payload.get("metadata", {})
    spec = payload.get("spec", {})
    status = payload.get("status", {})
    desired = int(spec.get("replicas", 1))
    observed = int(status.get("observedGeneration", 0))
    generation = int(metadata.get("generation", 0))
    available = int(status.get("availableReplicas", 0))
    ready = int(status.get("readyReplicas", 0))
    updated = int(status.get("updatedReplicas", 0))
    available_condition = any(
        item.get("type") == "Available" and item.get("status") == "True"
        for item in status.get("conditions", [])
    )
    return observed >= generation and available >= desired and ready >= desired and updated >= desired and available_condition


def artifact_identity_ready(payload: dict, repository: str, digest: str) -> bool:
    expected = f"{repository}@{digest}"
    containers = payload.get("spec", {}).get("template", {}).get("spec", {}).get("containers", [])
    return any(item.get("image") == expected for item in containers)


def endpoint_ready(payload: dict) -> bool:
    for item in payload.get("items", []):
        for endpoint in item.get("endpoints", []):
            conditions = endpoint.get("conditions", {})
            if endpoint.get("addresses") and conditions.get("ready", True) is not False:
                return True
    return False


def main() -> None:
    parser = argparse.ArgumentParser(description="Normalize read-only Azure/AKS observations into the platform verification contract.")
    parser.add_argument("--application", required=True)
    parser.add_argument("--environment", required=True, choices=["dev", "test", "prod"])
    parser.add_argument("--artifact-repository", required=True)
    parser.add_argument("--artifact-digest", required=True)
    parser.add_argument("--flux-json", required=True, type=Path)
    parser.add_argument("--deployment-json", required=True, type=Path)
    parser.add_argument("--endpoints-json", required=True, type=Path)
    parser.add_argument("--metrics-json", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    flux = load(args.flux_json)
    deployment = load(args.deployment_json)
    endpoints = load(args.endpoints_json)
    metrics = load(args.metrics_json) if args.metrics_json and args.metrics_json.is_file() else {}

    observation = {
        "apiVersion": "platform.verification/v1",
        "kind": "DeploymentObservation",
        "metadata": {"application": args.application, "environment": args.environment},
        "spec": {
            "artifactRepository": args.artifact_repository,
            "artifactDigest": args.artifact_digest,
            "fluxReady": flux_ready(flux),
            "artifactIdentityReady": artifact_identity_ready(deployment, args.artifact_repository, args.artifact_digest),
            "rolloutReady": deployment_ready(deployment),
            "healthEndpointReady": endpoint_ready(endpoints),
            "errorRatePercent": metrics.get("errorRatePercent"),
            "p95LatencyMs": metrics.get("p95LatencyMs"),
            "observedAt": datetime.now(timezone.utc).isoformat(),
            "source": "azure-flux+aks-readonly",
        },
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(observation, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(observation, indent=2))


if __name__ == "__main__":
    main()
