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
CONFIG_NAME="enterprise-cicd"
CONFIG_NAMESPACE="flux-system"
REPO_URL="https://github.com/iwacollection/k3s-gitops"
BRANCH="main"

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
  --kustomization "name=infra path=./enterprise-cicd/gitops/infrastructure prune=true"
  --kustomization "name=apps-dev path=./enterprise-cicd/gitops/environments/dev prune=true dependsOn=[infra]"
)

echo "========================================="
echo " AKS FLUX BOOTSTRAP"
echo "========================================="
echo "resource_group=$RESOURCE_GROUP"
echo "cluster=$CLUSTER_NAME"
echo "repository=$REPO_URL"
echo "branch=$BRANCH"
echo
printf 'command:'
printf ' %q' "${cmd[@]}"
printf '\n'

if [[ "$APPLY" -ne 1 ]]; then
  echo
  echo "PLAN ONLY: no Azure or AKS resources were changed."
  echo "Re-run with --apply only after this control-plane branch is merged and approvals are complete."
  exit 0
fi

echo
az account show --query '{subscription:name,subscriptionId:id,tenantId:tenantId}' -o table

echo
read -r -p "Type APPLY-FLUX to continue: " confirmation
if [[ "$confirmation" != "APPLY-FLUX" ]]; then
  echo "Cancelled."
  exit 3
fi

"${cmd[@]}"

echo
az k8s-configuration flux show \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-name "$CLUSTER_NAME" \
  --cluster-type managedClusters \
  --name "$CONFIG_NAME" \
  -o table
