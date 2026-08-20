#!/usr/bin/env bash
set -u

APPLY=0
if [[ "${1:-}" == "--apply" ]]; then
  APPLY=1
elif [[ -n "${1:-}" ]]; then
  echo "usage: $0 [--apply]" >&2
  exit 2
fi

RESOURCE_GROUP="group-test"
CLUSTER_NAME="k8s-test-cicd"
CONFIG_NAME="enterprise-cicd-test"
CONFIG_NAMESPACE="enterprise-cicd-test"
REPO_URL="https://github.com/iwacollection/k3s-gitops"
BRANCH="gitops/test"
KUSTOMIZATION_NAME="apps-test"
KUSTOMIZATION_PATH="./enterprise-cicd/gitops/environments/test"
API_VERSION="2025-04-01"

command -v az >/dev/null 2>&1 || { echo "Azure CLI is required." >&2; exit 1; }

SUBSCRIPTION_ID="$(az account show --query id -o tsv 2>/dev/null)"
TENANT_ID="$(az account show --query tenantId -o tsv 2>/dev/null)"
if [[ -z "$SUBSCRIPTION_ID" || -z "$TENANT_ID" ]]; then
  echo "Azure login is missing. Run az login first." >&2
  exit 1
fi

AKS_PARENT="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.ContainerService/managedClusters/${CLUSTER_NAME}"
FLUX_URL="https://management.azure.com${AKS_PARENT}/providers/Microsoft.KubernetesConfiguration/fluxConfigurations/${CONFIG_NAME}?api-version=${API_VERSION}"

print_plan() {
  cat <<EOF
=========================================
 AKS TEST FLUX BOOTSTRAP
=========================================
mode=PLAN ONLY
subscription=${SUBSCRIPTION_ID}
tenant=${TENANT_ID}
resource_group=${RESOURCE_GROUP}
cluster=${CLUSTER_NAME}
configuration=${CONFIG_NAME}
configuration_namespace=${CONFIG_NAMESPACE}
repository=${REPO_URL}
branch=${BRANCH}
kustomization=${KUSTOMIZATION_NAME}
path=${KUSTOMIZATION_PATH}

Planned write:
- Create/reuse Flux configuration ${CONFIG_NAME} on the existing AKS cluster.
- Reconcile only ${KUSTOMIZATION_PATH} from branch ${BRANCH}.
- Do not reconcile enterprise-cicd/gitops/infrastructure from TEST.
- Do not create a second AKS, VNet, ACR, or build artifact.

No Azure write has occurred.
Re-run with --apply using a privileged platform bootstrap operator.
EOF
}

if [[ "$APPLY" -ne 1 ]]; then
  print_plan
  exit 0
fi

echo "========================================="
echo " AKS TEST FLUX APPLY"
echo "========================================="
echo "subscription=${SUBSCRIPTION_ID}"
echo "tenant=${TENANT_ID}"
echo "configuration=${CONFIG_NAME}"
echo "branch=${BRANCH}"

echo "[1] Validate existing AKS"
az aks show --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" >/dev/null 2>&1 || { echo "AKS not found: ${RESOURCE_GROUP}/${CLUSTER_NAME}" >&2; exit 1; }

echo "[2] Create/reuse TEST Flux configuration through ARM REST"
if az rest --method get --url "$FLUX_URL" >/dev/null 2>&1; then
  echo "Flux configuration already exists: ${CONFIG_NAME}"
else
  BODY='{"properties":{"scope":"cluster","namespace":"enterprise-cicd-test","sourceKind":"GitRepository","suspend":false,"gitRepository":{"url":"https://github.com/iwacollection/k3s-gitops","repositoryRef":{"branch":"gitops/test"},"syncIntervalInSeconds":60,"timeoutInSeconds":120},"kustomizations":{"apps-test":{"path":"./enterprise-cicd/gitops/environments/test","prune":true,"force":false,"syncIntervalInSeconds":60,"retryIntervalInSeconds":60,"timeoutInSeconds":600}}}}'
  az rest --method put --url "$FLUX_URL" --body "$BODY" -o json || { echo "Failed to create TEST Flux configuration" >&2; exit 1; }
fi

echo "[3] Wait for provisioning"
for i in $(seq 1 40); do
  STATE="$(az rest --method get --url "$FLUX_URL" --query properties.provisioningState -o tsv 2>/dev/null)"
  echo "flux_state=${STATE}"
  [[ "$STATE" == "Succeeded" ]] && break
  [[ "$STATE" == "Failed" ]] && break
  sleep 10
done

echo "[4] Wait for reconciliation"
for i in $(seq 1 30); do
  COMPLIANCE="$(az rest --method get --url "$FLUX_URL" --query properties.complianceState -o tsv 2>/dev/null)"
  echo "flux_compliance=${COMPLIANCE}"
  [[ "$COMPLIANCE" == "Compliant" ]] && break
  sleep 10
done

echo "[5] Final TEST Flux status"
az rest --method get --url "$FLUX_URL" --query '{name:name,namespace:properties.namespace,provisioningState:properties.provisioningState,complianceState:properties.complianceState,repositoryUrl:properties.gitRepository.url,branch:properties.gitRepository.repositoryRef.branch,kustomizations:properties.kustomizations,sourceSyncedCommitId:properties.sourceSyncedCommitId,errorMessage:properties.errorMessage,statuses:properties.statuses}' -o json

echo "========================================="
echo " TEST FLUX ACTIVATION FINISHED"
echo " terminal remains open"
echo "========================================="
