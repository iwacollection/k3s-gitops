#!/usr/bin/env bash
set -euo pipefail
PR_ID=${PR_ID:?}
NAMESPACE="preview-${PR_ID}"
az aks get-credentials --resource-group "$TF_AKS_RG" --name "$TF_AKS_CLUSTER" --overwrite-existing
kubectl delete namespace "$NAMESPACE" || true
