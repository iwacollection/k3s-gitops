#!/usr/bin/env bash
set -euo pipefail

# Logical PROD GitOps activation on the existing Lab AKS.
# Default: PLAN ONLY. Pass --apply to create/update the ARM-owned namespace
# and Flux v2 configuration through Azure Resource Manager REST APIs.

APPLY=0
if [[ "${1:-}" == "--apply" ]]; then
  APPLY=1
elif [[ -n "${1:-}" ]]; then
  echo "usage: $0 [--apply]" >&2
  exit 2
fi

SUBSCRIPTION_ID_EXPECTED="c12c3a36-99d8-4741-bcef-cd7df5d5cd4a"
RESOURCE_GROUP="group-test"
CLUSTER_NAME="k8s-test-cicd"
APPLICATION_NAMESPACE="cicd-prod"
CONFIG_NAME="enterprise-cicd-prod"
CONFIG_NAMESPACE="enterprise-cicd-prod"
REPO_URL="https://github.com/iwacollection/k3s-gitops"
RAW_KUSTOMIZATION_URL="https://raw.githubusercontent.com/iwacollection/k3s-gitops/gitops/prod/enterprise-cicd/gitops/environments/prod/kustomization.yaml"
BRANCH="gitops/prod"
KUSTOMIZATION_NAME="apps-prod"
KUSTOMIZATION_PATH="./enterprise-cicd/gitops/environments/prod"
MANAGED_NAMESPACE_API_VERSION="2026-01-01"
FLUX_API_VERSION="2025-04-01"
RESULT_FILE="prod-flux-activation-result.json"

log() { printf '[prod-flux] %s\n' "$*"; }
fail() { printf '[prod-flux][ERROR] %s\n' "$*" >&2; exit 1; }

command -v az >/dev/null 2>&1 || fail "Azure CLI is required"
command -v python3 >/dev/null 2>&1 || fail "python3 is required"
az account show >/dev/null 2>&1 || fail "Azure CLI is not authenticated"

SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
TENANT_ID="$(az account show --query tenantId -o tsv)"
[[ "$SUBSCRIPTION_ID" == "$SUBSCRIPTION_ID_EXPECTED" ]] || fail "unexpected Azure subscription: $SUBSCRIPTION_ID"

AKS_PARENT="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.ContainerService/managedClusters/${CLUSTER_NAME}"
NAMESPACE_URL="https://management.azure.com${AKS_PARENT}/managedNamespaces/${APPLICATION_NAMESPACE}?api-version=${MANAGED_NAMESPACE_API_VERSION}"
FLUX_URL="https://management.azure.com${AKS_PARENT}/providers/Microsoft.KubernetesConfiguration/fluxConfigurations/${CONFIG_NAME}?api-version=${FLUX_API_VERSION}"

check_prod_branch_namespace_ownership() {
  python3 - "$RAW_KUSTOMIZATION_URL" <<'PY'
import sys
import time
import urllib.request

url = sys.argv[1]
last = None
for attempt in range(1, 6):
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "enterprise-prod-flux-activation/1.0"})
        with urllib.request.urlopen(req, timeout=30) as response:
            text = response.read().decode("utf-8")
        if "kind: Kustomization" not in text:
            raise RuntimeError("gitops/prod root is not a Kustomization")
        active_lines = [line.strip() for line in text.splitlines() if line.strip() and not line.lstrip().startswith("#")]
        if any("namespace.yaml" in line for line in active_lines):
            raise RuntimeError("gitops/prod still references namespace.yaml; ARM/Flux ownership would conflict")
        print("PROD_BRANCH_NAMESPACE_OWNERSHIP=ARM_ONLY")
        print(text)
        sys.exit(0)
    except Exception as exc:
        last = exc
        print(f"prod_branch_check_attempt={attempt} failed={exc}", file=sys.stderr)
        time.sleep(2)
print(f"unable to prove gitops/prod namespace ownership boundary: {last}", file=sys.stderr)
sys.exit(1)
PY
}

log "Validating existing shared AKS"
CLUSTER_JSON="$(az aks show --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" -o json)" || fail "AKS not found: ${RESOURCE_GROUP}/${CLUSTER_NAME}"
LOCATION="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["location"])' <<< "$CLUSTER_JSON")"
[[ -n "$LOCATION" ]] || fail "failed to resolve AKS location"

log "Checking gitops/prod Desired-State namespace ownership"
if [[ "$APPLY" -eq 1 ]]; then
  check_prod_branch_namespace_ownership || fail "gitops/prod is not ready for ARM-owned namespace activation"
fi

if [[ "$APPLY" -eq 0 ]]; then
  cat <<EOF
=========================================
 PROD LOGICAL GITOPS ACTIVATION PLAN
=========================================
mode=PLAN ONLY
subscription=${SUBSCRIPTION_ID}
tenant=${TENANT_ID}
resource_group=${RESOURCE_GROUP}
cluster=${CLUSTER_NAME}
location=${LOCATION}
application_namespace=${APPLICATION_NAMESPACE}
namespace_management=arm
flux_configuration=${CONFIG_NAME}
flux_namespace=${CONFIG_NAMESPACE}
repository=${REPO_URL}
branch=${BRANCH}
kustomization=${KUSTOMIZATION_NAME}
path=${KUSTOMIZATION_PATH}

Planned writes:
  1. Create/adopt ARM Managed Namespace ${APPLICATION_NAMESPACE} with adoptionPolicy=IfIdentical and deletePolicy=Keep.
  2. Create/update Flux configuration ${CONFIG_NAME} through ARM REST.
  3. Reconcile only ${KUSTOMIZATION_PATH} from ${BRANCH}.

Fail-closed prerequisites before --apply:
  - gitops/prod root must not reference namespace.yaml.
  - shared AKS must already exist.
  - no second AKS/VNet/ACR/database is created.
  - no application ReleaseRequest is promoted by this script.

No Azure write has occurred.
EOF
  exit 0
fi

log "Creating/adopting ARM-owned application namespace"
NAMESPACE_BODY="$(cat <<EOF
{
  "location": "${LOCATION}",
  "tags": {
    "managed_by": "enterprise-cicd-activation",
    "environment": "prod",
    "ownership": "arm-only-not-flux"
  },
  "properties": {
    "adoptionPolicy": "IfIdentical",
    "deletePolicy": "Keep",
    "labels": {
      "environment": "prod",
      "platform.iac/managed-by": "arm"
    }
  }
}
EOF
)"
az rest --method put --url "$NAMESPACE_URL" --headers 'Content-Type=application/json' --body "$NAMESPACE_BODY" -o json > /tmp/prod-managed-namespace-put.json

log "Waiting for ARM Managed Namespace provisioning"
NAMESPACE_STATE=""
for _ in $(seq 1 40); do
  NAMESPACE_STATE="$(az rest --method get --url "$NAMESPACE_URL" --query properties.provisioningState -o tsv 2>/dev/null || true)"
  echo "namespace_state=${NAMESPACE_STATE}"
  [[ "$NAMESPACE_STATE" == "Succeeded" ]] && break
  [[ "$NAMESPACE_STATE" == "Failed" ]] && break
  sleep 10
done
[[ "$NAMESPACE_STATE" == "Succeeded" ]] || fail "ARM Managed Namespace did not reach Succeeded: $NAMESPACE_STATE"

log "Verifying Managed Namespace ownership contract"
az rest --method get --url "$NAMESPACE_URL" \
  --query '{name:name,state:properties.provisioningState,adoptionPolicy:properties.adoptionPolicy,deletePolicy:properties.deletePolicy,labels:properties.labels,tags:tags}' \
  -o json > /tmp/prod-managed-namespace.json
python3 - /tmp/prod-managed-namespace.json <<'PY'
import json, sys
n=json.load(open(sys.argv[1]))
assert n['name']=='cicd-prod'
assert n['state']=='Succeeded'
assert n['adoptionPolicy']=='IfIdentical'
assert n['deletePolicy']=='Keep'
assert (n.get('tags') or {}).get('ownership')=='arm-only-not-flux'
print('PROD_MANAGED_NAMESPACE=READY')
PY

log "Creating/updating PROD Flux configuration through ARM REST"
FLUX_BODY="$(cat <<EOF
{
  "properties": {
    "scope": "cluster",
    "namespace": "${CONFIG_NAMESPACE}",
    "sourceKind": "GitRepository",
    "suspend": false,
    "waitForReconciliation": true,
    "reconciliationWaitDuration": "PT15M",
    "gitRepository": {
      "url": "${REPO_URL}",
      "repositoryRef": {
        "branch": "${BRANCH}"
      },
      "syncIntervalInSeconds": 60,
      "timeoutInSeconds": 120
    },
    "kustomizations": {
      "${KUSTOMIZATION_NAME}": {
        "path": "${KUSTOMIZATION_PATH}",
        "prune": true,
        "force": false,
        "wait": true,
        "syncIntervalInSeconds": 60,
        "retryIntervalInSeconds": 60,
        "timeoutInSeconds": 600
      }
    }
  }
}
EOF
)"
az rest --method put --url "$FLUX_URL" --headers 'Content-Type=application/json' --body "$FLUX_BODY" -o json > /tmp/prod-flux-put.json

log "Waiting for Flux provisioning"
FLUX_STATE=""
for _ in $(seq 1 60); do
  FLUX_STATE="$(az rest --method get --url "$FLUX_URL" --query properties.provisioningState -o tsv 2>/dev/null || true)"
  echo "flux_state=${FLUX_STATE}"
  [[ "$FLUX_STATE" == "Succeeded" ]] && break
  [[ "$FLUX_STATE" == "Failed" ]] && break
  sleep 10
done
[[ "$FLUX_STATE" == "Succeeded" ]] || fail "PROD Flux did not reach Succeeded: $FLUX_STATE"

log "Waiting for Flux compliance"
FLUX_COMPLIANCE=""
for _ in $(seq 1 60); do
  FLUX_COMPLIANCE="$(az rest --method get --url "$FLUX_URL" --query properties.complianceState -o tsv 2>/dev/null || true)"
  echo "flux_compliance=${FLUX_COMPLIANCE}"
  [[ "$FLUX_COMPLIANCE" == "Compliant" ]] && break
  sleep 10
done
[[ "$FLUX_COMPLIANCE" == "Compliant" ]] || fail "PROD Flux did not become Compliant: $FLUX_COMPLIANCE"

az rest --method get --url "$FLUX_URL" \
  --query '{name:name,namespace:properties.namespace,state:properties.provisioningState,compliance:properties.complianceState,repo:properties.gitRepository.url,branch:properties.gitRepository.repositoryRef.branch,sourceCommit:properties.sourceSyncedCommitId,error:properties.errorMessage}' \
  -o json > /tmp/prod-flux-final.json

python3 - /tmp/prod-managed-namespace.json /tmp/prod-flux-final.json "$RESULT_FILE" <<'PY'
import json, sys
namespace=json.load(open(sys.argv[1]))
flux=json.load(open(sys.argv[2]))
result={
  'status':'READY_FOR_PROD_RELEASE_PROMOTION',
  'namespace':namespace,
  'flux':flux,
  'namespaceOwnedByArm':True,
  'namespaceOwnedByFlux':False,
  'kubernetesWritePlane':'flux-only',
  'applicationPromoted':False,
}
assert flux['state']=='Succeeded'
assert flux['compliance']=='Compliant'
assert flux['branch']=='gitops/prod'
assert flux['namespace']=='enterprise-cicd-prod'
with open(sys.argv[3],'w') as fh:
    json.dump(result,fh,indent=2)
    fh.write('\n')
print(json.dumps(result,indent=2))
PY

log "PROD logical GitOps activation complete"
log "result=${RESULT_FILE}"
