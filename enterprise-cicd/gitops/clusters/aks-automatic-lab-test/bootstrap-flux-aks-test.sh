#!/usr/bin/env bash
set -euo pipefail

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

command -v az >/dev/null 2>&1 || {
  echo "Azure CLI is required." >&2
  exit 1
}

cmd=(
  az k8s-configuration flux create
  --resource-group "$RESOURCE_GROUP"
  --cluster-name "$CLUSTER_NAME"
  --cluster-type managedClusters
  --name "$CONFIG_NAME"
  --namespace "$CONFIG_NAMESPACE"
  --scope cluster
  --url "$REPO_URL"
  --branch "$BRANCH"
  --kustomization "name=${KUSTOMIZATION_NAME} path=${KUSTOMIZATION_PATH} prune=true"
)

echo "========================================="
echo " AKS TEST FLUX BOOTSTRAP"
echo "========================================="
echo "resource_group=$RESOURCE_GROUP"
echo "cluster=$CLUSTER_NAME"
echo "configuration=$CONFIG_NAME"
echo "configuration_namespace=$CONFIG_NAMESPACE"
echo "repository=$REPO_URL"
echo "branch=$BRANCH"
echo "kustomization=$KUSTOMIZATION_NAME"
echo "path=$KUSTOMIZATION_PATH"
echo
printf 'command:'
printf ' %q' "${cmd[@]}"
printf '\n'

if [[ "$APPLY" -ne 1 ]]; then
  echo
  echo "PLAN ONLY: no Azure or AKS resources were changed."
  echo "Re-run with --apply using a privileged platform bootstrap operator to create the TEST Flux configuration."
  exit 0
fi

echo
az account show --query '{subscription:name,subscriptionId:id,tenantId:tenantId}' -o table

if az k8s-configuration flux show \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-name "$CLUSTER_NAME" \
  --cluster-type managedClusters \
  --name "$CONFIG_NAME" >/dev/null 2>&1; then
  echo "Flux configuration already exists: $CONFIG_NAME"
else
  "${cmd[@]}"
fi

echo
az k8s-configuration flux show \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-name "$CLUSTER_NAME" \
  --cluster-type managedClusters \
  --name "$CONFIG_NAME" \
  --query '{name:name,namespace:namespace,provisioningState:provisioningState,complianceState:complianceState,repositoryUrl:gitRepository.url,branch:gitRepository.repositoryRef.branch,kustomizations:kustomizations}' \
  -o json
