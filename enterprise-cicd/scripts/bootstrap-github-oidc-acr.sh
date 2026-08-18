#!/usr/bin/env bash
set -euo pipefail

# One-time Azure bootstrap for GitHub Actions -> ACR -> existing AKS.
# Creates only CI/CD identity + Standard ACR and RBAC assignments.

RESOURCE_GROUP="${RESOURCE_GROUP:-group-test}"
LOCATION="${LOCATION:-eastus}"
AKS_CLUSTER="${AKS_CLUSTER:-k8s-test-cicd}"
GITHUB_OWNER="${GITHUB_OWNER:-iwacollection}"
GITHUB_REPO="${GITHUB_REPO:-k3s-gitops}"
FEATURE_BRANCH="${FEATURE_BRANCH:-feature/azure-enterprise-cicd-bootstrap-v1}"
NAMESPACE="${NAMESPACE:-cicd-dev}"
IDENTITY_NAME="${IDENTITY_NAME:-github-cicd-uami}"

SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-$(az account show --query id -o tsv)}"
TENANT_ID="${TENANT_ID:-$(az account show --query tenantId -o tsv)}"

if [[ -z "$SUBSCRIPTION_ID" || -z "$TENANT_ID" ]]; then
  echo "ERROR: Azure login/subscription is not available." >&2
  exit 2
fi

az account set --subscription "$SUBSCRIPTION_ID"

# Deterministic, globally likely-unique ACR name; override with ACR_NAME if needed.
if [[ -z "${ACR_NAME:-}" ]]; then
  HASH="$(printf '%s' "${SUBSCRIPTION_ID}-${GITHUB_OWNER}-${GITHUB_REPO}" | sha256sum | awk '{print $1}' | cut -c1-12)"
  ACR_NAME="cicd${HASH}"
fi

section() {
  printf '\n%s\n' "$1"
}

ensure_role() {
  local role="$1"
  local scope="$2"
  local object_id="$3"

  local count
  count="$(az role assignment list \
    --assignee "$object_id" \
    --scope "$scope" \
    --query "[?roleDefinitionName=='${role}'] | length(@)" \
    -o tsv 2>/dev/null || echo 0)"

  if [[ "$count" == "0" ]]; then
    echo "Assign role: $role"
    az role assignment create \
      --assignee-object-id "$object_id" \
      --assignee-principal-type ServicePrincipal \
      --role "$role" \
      --scope "$scope" \
      --only-show-errors >/dev/null
  else
    echo "Role already present: $role"
  fi
}

put_fic() {
  local name="$1"
  local subject="$2"
  local identity_id="$3"

  echo "Configure federated credential: $name"
  az rest \
    --method put \
    --url "https://management.azure.com${identity_id}/federatedIdentityCredentials/${name}?api-version=2023-01-31" \
    --headers Content-Type=application/json \
    --body "{\"properties\":{\"issuer\":\"https://token.actions.githubusercontent.com\",\"subject\":\"${subject}\",\"audiences\":[\"api://AzureADTokenExchange\"]}}" \
    --only-show-errors >/dev/null
}

echo "========================================="
echo " GITHUB OIDC + ACR + AKS BOOTSTRAP"
echo "========================================="
echo "subscription=$SUBSCRIPTION_ID"
echo "tenant=$TENANT_ID"
echo "resource_group=$RESOURCE_GROUP"
echo "aks=$AKS_CLUSTER"
echo "acr=$ACR_NAME"
echo "namespace=$NAMESPACE"

section "[1] Ensure resource group exists"
if ! az group show --name "$RESOURCE_GROUP" --only-show-errors >/dev/null 2>&1; then
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --only-show-errors >/dev/null
fi

section "[2] Ensure Standard ACR"
if ! az acr show --name "$ACR_NAME" --only-show-errors >/dev/null 2>&1; then
  az acr create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$ACR_NAME" \
    --sku Standard \
    --admin-enabled false \
    --location "$LOCATION" \
    --only-show-errors >/dev/null
fi
ACR_ID="$(az acr show --name "$ACR_NAME" --query id -o tsv)"
ACR_LOGIN_SERVER="$(az acr show --name "$ACR_NAME" --query loginServer -o tsv)"

section "[3] Ensure GitHub CI managed identity"
if ! az identity show --resource-group "$RESOURCE_GROUP" --name "$IDENTITY_NAME" --only-show-errors >/dev/null 2>&1; then
  az identity create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$IDENTITY_NAME" \
    --location "$LOCATION" \
    --only-show-errors >/dev/null
fi
IDENTITY_ID="$(az identity show --resource-group "$RESOURCE_GROUP" --name "$IDENTITY_NAME" --query id -o tsv)"
CLIENT_ID="$(az identity show --resource-group "$RESOURCE_GROUP" --name "$IDENTITY_NAME" --query clientId -o tsv)"
PRINCIPAL_ID="$(az identity show --resource-group "$RESOURCE_GROUP" --name "$IDENTITY_NAME" --query principalId -o tsv)"

section "[4] Configure GitHub OIDC trust"
put_fic \
  "github-feature-branch" \
  "repo:${GITHUB_OWNER}/${GITHUB_REPO}:ref:refs/heads/${FEATURE_BRANCH}" \
  "$IDENTITY_ID"
put_fic \
  "github-main" \
  "repo:${GITHUB_OWNER}/${GITHUB_REPO}:ref:refs/heads/main" \
  "$IDENTITY_ID"

section "[5] Grant GitHub CI AcrPush"
ensure_role "AcrPush" "$ACR_ID" "$PRINCIPAL_ID"

section "[6] Resolve AKS and create deployment namespace"
AKS_ID="$(az aks show --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER" --query id -o tsv)"
AKS_CONFIG="${AKS_CONFIG:-$HOME/.kube/aks-${AKS_CLUSTER}.yaml}"
mkdir -p "$(dirname "$AKS_CONFIG")"
az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_CLUSTER" \
  --file "$AKS_CONFIG" \
  --overwrite-existing \
  --only-show-errors >/dev/null
if command -v kubelogin >/dev/null 2>&1; then
  kubelogin convert-kubeconfig -l azurecli --kubeconfig "$AKS_CONFIG" >/dev/null
fi
KUBECTL_BIN="${KUBECTL_BIN:-$(command -v kubectl-aks || command -v kubectl)}"
KUBECONFIG="$AKS_CONFIG" "$KUBECTL_BIN" create namespace "$NAMESPACE" --dry-run=client -o yaml \
  | KUBECONFIG="$AKS_CONFIG" "$KUBECTL_BIN" apply -f - >/dev/null

section "[7] Grant CI access to AKS"
ensure_role "Azure Kubernetes Service Cluster User Role" "$AKS_ID" "$PRINCIPAL_ID"
ensure_role "Azure Kubernetes Service RBAC Writer" "$AKS_ID/namespaces/$NAMESPACE" "$PRINCIPAL_ID"

section "[8] Grant AKS kubelet identity AcrPull"
KUBELET_OBJECT_ID="$(az rest \
  --method get \
  --url "https://management.azure.com${AKS_ID}?api-version=2026-04-01" \
  --query 'properties.identityProfile.kubeletidentity.objectId' \
  -o tsv 2>/dev/null || true)"
if [[ -n "$KUBELET_OBJECT_ID" && "$KUBELET_OBJECT_ID" != "None" ]]; then
  ensure_role "AcrPull" "$ACR_ID" "$KUBELET_OBJECT_ID"
else
  echo "WARNING: kubelet identity objectId not returned; image pull role must be verified separately."
fi

section "[9] Write local bootstrap outputs"
OUTPUT_FILE="${OUTPUT_FILE:-github_oidc_bootstrap.env}"
cat > "$OUTPUT_FILE" <<EOF
AZURE_CLIENT_ID=$CLIENT_ID
AZURE_TENANT_ID=$TENANT_ID
AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID
AZURE_RESOURCE_GROUP=$RESOURCE_GROUP
AZURE_AKS_CLUSTER=$AKS_CLUSTER
AZURE_ACR_NAME=$ACR_NAME
AZURE_ACR_LOGIN_SERVER=$ACR_LOGIN_SERVER
K8S_NAMESPACE=$NAMESPACE
EOF
chmod 600 "$OUTPUT_FILE"

section "========================================="
echo " BOOTSTRAP SUCCESS"
echo "========================================="
echo "output=$OUTPUT_FILE"
echo "acr=$ACR_LOGIN_SERVER"
echo "identity_client_id=$CLIENT_ID"
echo "namespace=$NAMESPACE"
section "Next: run GitHub workflow 'azure-aks-smoke-deploy' from this branch and paste values from $OUTPUT_FILE into workflow_dispatch inputs."
