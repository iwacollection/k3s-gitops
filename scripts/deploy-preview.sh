#!/usr/bin/env bash
set -euo pipefail
IMAGE=${IMAGE:?}
PR_ID=${PR_ID:-preview}
NAMESPACE="preview-${PR_ID}"

echo "Using image: $IMAGE"

az aks get-credentials --resource-group "$TF_AKS_RG" --name "$TF_AKS_CLUSTER" --overwrite-existing
kubectl create namespace "$NAMESPACE" || true
# generate a simple kustomization that sets the image
cat > /tmp/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../apps/example-service/k8s/base/deployment.yaml
images:
  - name: REPLACE_IMAGE
    newName: ${IMAGE}
EOF
kubectl -n "$NAMESPACE" apply -k /tmp

echo "Preview deployed to namespace $NAMESPACE"
