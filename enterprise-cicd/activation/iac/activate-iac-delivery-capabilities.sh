#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT=""
APPLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --environment) ENVIRONMENT="${2:-}"; shift 2 ;;
    --apply) APPLY=1; shift ;;
    *) echo "usage: $0 --environment dev|test|prod [--apply]" >&2; exit 2 ;;
  esac
done

[[ "$ENVIRONMENT" =~ ^(dev|test|prod)$ ]] || { echo "--environment must be dev, test or prod" >&2; exit 2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EDGE_SCRIPT="${SCRIPT_DIR}/activate-iac-edge-network-capability.sh"
IAM_SCRIPT="${SCRIPT_DIR}/activate-iac-iam-capability.sh"
WORKLOAD_SCRIPT="${SCRIPT_DIR}/activate-iac-workload-services-capability.sh"
RESULT_FILE="${ENVIRONMENT}-iac-delivery-capabilities-result.json"
EDGE_RESULT="${ENVIRONMENT}-iac-edge-capability-result.json"
IAM_RESULT="${ENVIRONMENT}-iac-iam-capability-result.json"
WORKLOAD_RESULT="${ENVIRONMENT}-iac-workload-capability-result.json"

log(){ printf '[iac-delivery-%s] %s\n' "$ENVIRONMENT" "$*"; }
fail(){ printf '[iac-delivery-%s][ERROR] %s\n' "$ENVIRONMENT" "$*" >&2; exit 1; }

for dependency in "$EDGE_SCRIPT" "$IAM_SCRIPT" "$WORKLOAD_SCRIPT"; do
  [[ -f "$dependency" ]] || fail "missing activation dependency: $dependency"
  bash -n "$dependency" || fail "invalid activation dependency: $dependency"
done

if [[ "$APPLY" -eq 0 ]]; then
  log "PLAN ONLY - no Azure mutation"
  echo
  "$EDGE_SCRIPT" --environment "$ENVIRONMENT"
  echo
  "$IAM_SCRIPT" --environment "$ENVIRONMENT"
  echo
  "$WORKLOAD_SCRIPT" --environment "$ENVIRONMENT"
  echo
  cat <<EOF
Delivery capability activation plan completed.
No Azure resource mutation was performed.

When explicitly approved, run:
  $0 --environment ${ENVIRONMENT} --apply

This activates three isolated protected Apply planes:
  - iac-${ENVIRONMENT}-edge-apply: Standard Load Balancer and VPN Gateway foundation
  - iac-${ENVIRONMENT}-iam-apply: conditioned low-risk IAM role binding
  - iac-${ENVIRONMENT}-workload-apply: ACR, Storage, Key Vault, Service Bus, Managed Redis and PostgreSQL Flexible
EOF
  exit 0
fi

log "APPLY mode enabled"
log "Activating protected Edge network capability"
"$EDGE_SCRIPT" --environment "$ENVIRONMENT" --apply
[[ -f "$EDGE_RESULT" ]] || fail "Edge activation result missing: $EDGE_RESULT"

log "Activating conditioned IAM capability"
"$IAM_SCRIPT" --environment "$ENVIRONMENT" --apply
[[ -f "$IAM_RESULT" ]] || fail "IAM activation result missing: $IAM_RESULT"

log "Activating protected workload services capability"
"$WORKLOAD_SCRIPT" --environment "$ENVIRONMENT" --apply
[[ -f "$WORKLOAD_RESULT" ]] || fail "Workload activation result missing: $WORKLOAD_RESULT"

python3 - "$EDGE_RESULT" "$IAM_RESULT" "$WORKLOAD_RESULT" "$RESULT_FILE" "$ENVIRONMENT" <<'PY'
import json
import sys
from pathlib import Path

edge_path, iam_path, workload_path, result_path, environment = sys.argv[1:]
edge = json.loads(Path(edge_path).read_text())
iam = json.loads(Path(iam_path).read_text())
workload = json.loads(Path(workload_path).read_text())

assert edge["status"] == "READY_FOR_IAC_EDGE_GITHUB_BINDING"
assert edge["environment"] == environment
for key in ("genericNetworkContributor", "peeringWrite", "natGatewayWrite", "applicationGatewayWrite", "vpnConnectionWrite", "roleAssignmentWrite"):
    assert edge[key] is False

assert iam["status"] == "READY_FOR_IAC_IAM_GITHUB_BINDING"
assert iam["environment"] == environment
assert iam["allowedPrincipalType"] == "ServicePrincipal"
for key in ("subscriptionRootTargetAllowedByRenderer", "ownerAllowed", "contributorAllowed", "userAccessAdministratorAllowed", "arbitraryRoleAssignmentAllowed"):
    assert iam[key] is False

assert workload["status"] == "READY_FOR_IAC_WORKLOAD_GITHUB_BINDING"
assert workload["environment"] == environment
assert set(workload["supportedServices"]) == {"acr", "storage", "key-vault", "service-bus", "managed-redis", "postgresql-flexible"}
for key in ("roleAssignmentWrite", "serviceCredentialRead", "keyVaultSecretDataAccess", "genericNetworkContributor"):
    assert workload[key] is False

result = {
    "status": "READY_FOR_IAC_DELIVERY_BINDINGS",
    "environment": environment,
    "edge": edge,
    "iam": iam,
    "workload": workload,
}
Path(result_path).write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps(result, indent=2))
PY

log "Delivery capability activation complete: ${RESULT_FILE}"
