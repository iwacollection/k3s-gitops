#!/usr/bin/env bash

set -u

LOG="${1:-github_azure_dev_bootstrap.log}"

(
  set -euo pipefail

  REPO="iwacollection/k3s-gitops"
  GH_ENV="dev"
  RG="group-test"
  AKS="k8s-test-cicd"
  LOCATION="eastus"
  IDENTITY_NAME="uami-github-cicd-dev"

  SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
  TENANT_ID="$(az account show --query tenantId -o tsv)"
  SUB_SHORT="$(printf '%s' "$SUBSCRIPTION_ID" | tr -d '-' | cut -c1-10)"
  ACR_NAME="acrcicd${SUB_SHORT}"

  echo "========================================="
  echo " GITHUB -> AZURE DEV BOOTSTRAP"
  echo "========================================="
  echo "repository=$REPO"
  echo "github_environment=$GH_ENV"
  echo "resource_group=$RG"
  echo "aks_cluster=$AKS"
  echo "acr_name=$ACR_NAME"

  echo
  echo "[1] Ensure ACR Standard"
  if az acr show --name "$ACR_NAME" >/dev/null 2>&1; then
    echo "ACR already exists: $ACR_NAME"
  else
    az acr create \
      --resource-group "$RG" \
      --name "$ACR_NAME" \
      --sku Standard \
      --admin-enabled false \
      --location "$LOCATION" \
      --tags platform=enterprise-cicd environment=dev managed-by=bootstrap \
      --output none
    echo "ACR created: $ACR_NAME"
  fi

  ACR_ID="$(az acr show --name "$ACR_NAME" --query id -o tsv)"

  echo
  echo "[2] Ensure GitHub deployment identity"
  if az identity show --resource-group "$RG" --name "$IDENTITY_NAME" >/dev/null 2>&1; then
    echo "Managed identity already exists: $IDENTITY_NAME"
  else
    az identity create \
      --resource-group "$RG" \
      --name "$IDENTITY_NAME" \
      --location "$LOCATION" \
      --output none
    echo "Managed identity created: $IDENTITY_NAME"
  fi

  CLIENT_ID="$(az identity show -g "$RG" -n "$IDENTITY_NAME" --query clientId -o tsv)"
  PRINCIPAL_ID="$(az identity show -g "$RG" -n "$IDENTITY_NAME" --query principalId -o tsv)"
  IDENTITY_ID="$(az identity show -g "$RG" -n "$IDENTITY_NAME" --query id -o tsv)"

  echo
  echo "[3] Configure GitHub OIDC federation"
  FIC_NAME="github-${GH_ENV}"
  FIC_URI="https://management.azure.com${IDENTITY_ID}/federatedIdentityCredentials/${FIC_NAME}?api-version=2023-01-31"

  FIC_BODY="$(cat <<EOF
{
  \"properties\": {
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:${REPO}:environment:${GH_ENV}\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }
}
EOF
)"

  az rest \
    --method put \
    --uri "$FIC_URI" \
    --body "$FIC_BODY" \
    --output none

  echo "Federated credential ready: repo:${REPO}:environment:${GH_ENV}"

  echo
  echo "[4] Grant ACR push to GitHub identity"
  az role assignment create \
    --assignee-object-id "$PRINCIPAL_ID" \
    --assignee-principal-type ServicePrincipal \
    --role AcrPush \
    --scope "$ACR_ID" \
    --output none 2>/dev/null || true
  echo "AcrPush ready"

  echo
  echo "[5] Grant AKS deploy permission to GitHub identity"
  AKS_ID="$(az aks show -g "$RG" -n "$AKS" --query id -o tsv)"
  az role assignment create \
    --assignee-object-id "$PRINCIPAL_ID" \
    --assignee-principal-type ServicePrincipal \
    --role "Azure Kubernetes Service RBAC Cluster Admin" \
    --scope "$AKS_ID" \
    --output none 2>/dev/null || true
  echo "AKS RBAC Cluster Admin ready for dev bootstrap"

  echo
  echo "[6] Grant ACR pull to AKS kubelet identity"
  AKS_ARM_URI="https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG}/providers/Microsoft.ContainerService/managedClusters/${AKS}?api-version=2026-04-01"
  KUBELET_OBJECT_ID="$(az rest --method get --uri "$AKS_ARM_URI" --query 'properties.identityProfile.kubeletidentity.objectId' -o tsv 2>/dev/null || true)"

  if [ -n "$KUBELET_OBJECT_ID" ] && [ "$KUBELET_OBJECT_ID" != "None" ]; then
    az role assignment create \
      --assignee-object-id "$KUBELET_OBJECT_ID" \
      --assignee-principal-type ServicePrincipal \
      --role AcrPull \
      --scope "$ACR_ID" \
      --output none 2>/dev/null || true
    echo "AcrPull ready for AKS kubelet identity"
  else
    echo "WARNING: kubelet identity was not returned by ARM; image pull role still needs verification"
  fi

  echo
  echo "========================================="
  echo " BOOTSTRAP SUCCESS"
  echo "========================================="
  echo
  echo "Create GitHub Environment: dev"
  echo "Then add these 3 Environment Secrets:"
  echo
  echo "AZURE_CLIENT_ID=$CLIENT_ID"
  echo "AZURE_TENANT_ID=$TENANT_ID"
  echo "AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID"
  echo
  echo "ACR_NAME=$ACR_NAME"
  echo
  echo "After secrets are set, run GitHub Actions workflow:"
  echo "Azure Dev Smoke Deploy"

) 2>&1 | tee "$LOG"
