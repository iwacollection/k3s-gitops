#!/usr/bin/env bash
set -euo pipefail

APPLY=0
if [[ "${1:-}" == "--apply" ]]; then
  APPLY=1
elif [[ -n "${1:-}" ]]; then
  echo "usage: $0 [--apply]" >&2
  exit 2
fi

IDENTITY_RESOURCE_GROUP="sub-test"
IDENTITY_NAME="k3s-gitops-test-uami"
FEDERATED_CREDENTIAL_NAME="github-k3s-gitops-test"
ISSUER="https://token.actions.githubusercontent.com"
SUBJECT="repo:iwacollection/k3s-gitops:environment:test"
AUDIENCE="api://AzureADTokenExchange"
TARGET_RESOURCE_GROUP="group-test"
AKS_CLUSTER="k8s-test-cicd"
TEST_NAMESPACE="cicd-test"
ACR_NAME="acrcicdc12c3a3699d8"

command -v az >/dev/null 2>&1 || {
  echo "Azure CLI is required." >&2
  exit 1
}

SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
TENANT_ID="$(az account show --query tenantId -o tsv)"
RG_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${TARGET_RESOURCE_GROUP}"
AKS_ID="${RG_ID}/providers/Microsoft.ContainerService/managedClusters/${AKS_CLUSTER}"
TEST_NAMESPACE_SCOPE="${AKS_ID}/namespaces/${TEST_NAMESPACE}"
ACR_ID="${RG_ID}/providers/Microsoft.ContainerRegistry/registries/${ACR_NAME}"

print_plan() {
  cat <<EOF
=========================================
 TEST OIDC IDENTITY ACTIVATION
=========================================
mode=PLAN ONLY
subscription=${SUBSCRIPTION_ID}
tenant=${TENANT_ID}
identity_resource_group=${IDENTITY_RESOURCE_GROUP}
identity_name=${IDENTITY_NAME}
federated_subject=${SUBJECT}
target_aks=${AKS_CLUSTER}
target_namespace=${TEST_NAMESPACE}
target_acr=${ACR_NAME}

Planned writes:
1. Create/reuse dedicated TEST user-assigned managed identity.
2. Create/reuse GitHub OIDC federated credential for environment:test.
3. Assign Reader on resource group ${TARGET_RESOURCE_GROUP}.
4. Assign Azure Kubernetes Service Cluster User Role on AKS.
5. Assign Azure Kubernetes Service RBAC Reader only on namespace ${TEST_NAMESPACE}.
6. Assign AcrPull on ${ACR_NAME}.

Forbidden by contract:
- Owner / Contributor / User Access Administrator on TEST runtime identity
- Azure Kubernetes Service RBAC Writer/Admin
- AcrPush
- any DEV namespace RBAC grant

No Azure write has occurred.
Re-run with --apply using a privileged platform bootstrap operator to activate.
EOF
}

if [[ "$APPLY" -ne 1 ]]; then
  print_plan
  exit 0
fi

echo "========================================="
echo " TEST OIDC IDENTITY APPLY"
echo "========================================="
az account show --query '{subscription:name,subscriptionId:id,tenantId:tenantId}' -o table

if ! az group show --name "$IDENTITY_RESOURCE_GROUP" >/dev/null 2>&1; then
  echo "Identity resource group does not exist: $IDENTITY_RESOURCE_GROUP" >&2
  exit 1
fi

if ! az identity show --resource-group "$IDENTITY_RESOURCE_GROUP" --name "$IDENTITY_NAME" >/dev/null 2>&1; then
  az identity create --resource-group "$IDENTITY_RESOURCE_GROUP" --name "$IDENTITY_NAME" >/dev/null
fi

CLIENT_ID="$(az identity show --resource-group "$IDENTITY_RESOURCE_GROUP" --name "$IDENTITY_NAME" --query clientId -o tsv)"
PRINCIPAL_ID="$(az identity show --resource-group "$IDENTITY_RESOURCE_GROUP" --name "$IDENTITY_NAME" --query principalId -o tsv)"
IDENTITY_ID="$(az identity show --resource-group "$IDENTITY_RESOURCE_GROUP" --name "$IDENTITY_NAME" --query id -o tsv)"

if ! az identity federated-credential show \
  --resource-group "$IDENTITY_RESOURCE_GROUP" \
  --identity-name "$IDENTITY_NAME" \
  --name "$FEDERATED_CREDENTIAL_NAME" >/dev/null 2>&1; then
  az identity federated-credential create \
    --resource-group "$IDENTITY_RESOURCE_GROUP" \
    --identity-name "$IDENTITY_NAME" \
    --name "$FEDERATED_CREDENTIAL_NAME" \
    --issuer "$ISSUER" \
    --subject "$SUBJECT" \
    --audiences "$AUDIENCE" >/dev/null
fi

ensure_role() {
  local role="$1"
  local scope="$2"
  local existing
  existing="$(az role assignment list \
    --assignee-object-id "$PRINCIPAL_ID" \
    --scope "$scope" \
    --query "[?roleDefinitionName=='${role}'] | [0].id" \
    -o tsv 2>/dev/null || true)"
  if [[ -z "$existing" ]]; then
    az role assignment create \
      --assignee-object-id "$PRINCIPAL_ID" \
      --assignee-principal-type ServicePrincipal \
      --role "$role" \
      --scope "$scope" >/dev/null
  fi
}

ensure_role "Reader" "$RG_ID"
ensure_role "Azure Kubernetes Service Cluster User Role" "$AKS_ID"
ensure_role "Azure Kubernetes Service RBAC Reader" "$TEST_NAMESPACE_SCOPE"
ensure_role "AcrPull" "$ACR_ID"

cat <<EOF
=========================================
 TEST IDENTITY ACTIVATED
=========================================
clientId=${CLIENT_ID}
principalId=${PRINCIPAL_ID}
tenantId=${TENANT_ID}
subscriptionId=${SUBSCRIPTION_ID}
resourceId=${IDENTITY_ID}
federatedSubject=${SUBJECT}

Next governed step:
Update enterprise-cicd/contracts/environment-bindings.json test.identities.githubOidc with these exact IDs, then re-run Azure TEST Readiness Inventory.
EOF
