#!/usr/bin/env bash
set -u

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
RESULT_FILE="${TEST_IDENTITY_RESULT_FILE:-test-identity-activation-result.json}"

READER_ROLE_ID="acdd72a7-3385-48ef-bd42-f606fba81ae7"
AKS_CLUSTER_USER_ROLE_ID="4abbcc35-e782-43d8-92c5-2d3f1bd2253f"
AKS_RBAC_READER_ROLE_ID="7f6c6a51-bcf8-42ba-9220-52d62157d7db"
ACR_PULL_ROLE_ID="7f951dda-4ed3-4680-a7ca-43fe172d538d"

command -v az >/dev/null 2>&1 || { echo "Azure CLI is required." >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required." >&2; exit 1; }

SUBSCRIPTION_ID="$(az account show --query id -o tsv 2>/dev/null)"
TENANT_ID="$(az account show --query tenantId -o tsv 2>/dev/null)"
if [[ -z "$SUBSCRIPTION_ID" || -z "$TENANT_ID" ]]; then
  echo "Azure login is missing. Run az login first." >&2
  exit 1
fi

RG_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${TARGET_RESOURCE_GROUP}"
AKS_ID="${RG_ID}/providers/Microsoft.ContainerService/managedClusters/${AKS_CLUSTER}"
TEST_NAMESPACE_SCOPE="${AKS_ID}/namespaces/${TEST_NAMESPACE}"
ACR_ID="${RG_ID}/providers/Microsoft.ContainerRegistry/registries/${ACR_NAME}"
IDENTITY_ARM_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${IDENTITY_RESOURCE_GROUP}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${IDENTITY_NAME}"

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
result_file=${RESULT_FILE}

Planned writes:
1. Create/reuse dedicated TEST user-assigned managed identity.
2. Create/reuse GitHub OIDC federated credential for environment:test via ARM REST.
3. Assign Reader only on AKS ${AKS_CLUSTER}.
4. Assign Azure Kubernetes Service Cluster User Role on AKS.
5. Assign Azure Kubernetes Service RBAC Reader only on namespace ${TEST_NAMESPACE}.
6. Assign AcrPull on ${ACR_NAME}.

Forbidden by contract:
- resource-group-wide Reader for the TEST runtime identity
- Owner / Contributor / User Access Administrator
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
echo "subscription=${SUBSCRIPTION_ID}"
echo "tenant=${TENANT_ID}"
echo "result_file=${RESULT_FILE}"

echo "[1] Validate target resources"
az group show --name "$IDENTITY_RESOURCE_GROUP" >/dev/null 2>&1 || { echo "Identity resource group does not exist: $IDENTITY_RESOURCE_GROUP" >&2; exit 1; }
az aks show --resource-group "$TARGET_RESOURCE_GROUP" --name "$AKS_CLUSTER" >/dev/null 2>&1 || { echo "AKS not found: $TARGET_RESOURCE_GROUP/$AKS_CLUSTER" >&2; exit 1; }
az acr show --resource-group "$TARGET_RESOURCE_GROUP" --name "$ACR_NAME" >/dev/null 2>&1 || { echo "ACR not found: $TARGET_RESOURCE_GROUP/$ACR_NAME" >&2; exit 1; }

echo "[2] Create/reuse TEST UAMI"
if ! az identity show --resource-group "$IDENTITY_RESOURCE_GROUP" --name "$IDENTITY_NAME" >/dev/null 2>&1; then
  az identity create --resource-group "$IDENTITY_RESOURCE_GROUP" --name "$IDENTITY_NAME" >/dev/null || { echo "Failed to create TEST UAMI" >&2; exit 1; }
fi

CLIENT_ID="$(az identity show --resource-group "$IDENTITY_RESOURCE_GROUP" --name "$IDENTITY_NAME" --query clientId -o tsv)"
PRINCIPAL_ID="$(az identity show --resource-group "$IDENTITY_RESOURCE_GROUP" --name "$IDENTITY_NAME" --query principalId -o tsv)"
IDENTITY_ID="$(az identity show --resource-group "$IDENTITY_RESOURCE_GROUP" --name "$IDENTITY_NAME" --query id -o tsv)"

[[ -n "$CLIENT_ID" && -n "$PRINCIPAL_ID" && -n "$IDENTITY_ID" ]] || { echo "Failed to resolve TEST UAMI IDs" >&2; exit 1; }

echo "clientId=${CLIENT_ID}"
echo "principalId=${PRINCIPAL_ID}"

echo "[3] Create/reuse GitHub TEST federated credential via ARM REST"
FIC_URL="https://management.azure.com${IDENTITY_ARM_ID}/federatedIdentityCredentials/${FEDERATED_CREDENTIAL_NAME}?api-version=2024-11-30"
if ! az rest --method get --url "$FIC_URL" >/dev/null 2>&1; then
  az rest --method put --url "$FIC_URL" --body "{\"properties\":{\"issuer\":\"${ISSUER}\",\"subject\":\"${SUBJECT}\",\"audiences\":[\"${AUDIENCE}\"]}}" >/dev/null || { echo "Failed to create TEST federated credential" >&2; exit 1; }
fi

ensure_role_rest() {
  local role_name="$1"
  local role_id="$2"
  local scope="$3"
  local list_url encoded_scope existing assignment_id role_definition

  encoded_scope="$scope"
  list_url="https://management.azure.com${encoded_scope}/providers/Microsoft.Authorization/roleAssignments?api-version=2022-04-01&%24filter=principalId%20eq%20%27${PRINCIPAL_ID}%27"
  existing="$(az rest --method get --url "$list_url" -o json 2>/dev/null || echo '{\"value\":[]}')"
  role_definition="/subscriptions/${SUBSCRIPTION_ID}/providers/Microsoft.Authorization/roleDefinitions/${role_id}"

  if jq -e --arg rd "$role_definition" '.value[]? | select(.properties.roleDefinitionId == $rd)' >/dev/null 2>&1 <<<"$existing"; then
    echo "existing role: ${role_name}"
    return 0
  fi

  assignment_id="$(cat /proc/sys/kernel/random/uuid)"
  az rest --method put --url "https://management.azure.com${scope}/providers/Microsoft.Authorization/roleAssignments/${assignment_id}?api-version=2022-04-01" --body "{\"properties\":{\"principalId\":\"${PRINCIPAL_ID}\",\"principalType\":\"ServicePrincipal\",\"roleDefinitionId\":\"${role_definition}\"}}" >/dev/null || { echo "Failed role assignment: ${role_name}" >&2; return 1; }
  echo "created role: ${role_name}"
}

echo "[4] Grant minimum Azure/AKS/ACR roles"
ensure_role_rest "Reader" "$READER_ROLE_ID" "$AKS_ID" || exit 1
ensure_role_rest "Azure Kubernetes Service Cluster User Role" "$AKS_CLUSTER_USER_ROLE_ID" "$AKS_ID" || exit 1
ensure_role_rest "Azure Kubernetes Service RBAC Reader" "$AKS_RBAC_READER_ROLE_ID" "$TEST_NAMESPACE_SCOPE" || exit 1
ensure_role_rest "AcrPull" "$ACR_PULL_ROLE_ID" "$ACR_ID" || exit 1

echo "[5] Verify federated credential"
az rest --method get --url "$FIC_URL" --query "{name:name,issuer:properties.issuer,subject:properties.subject,audiences:properties.audiences}" -o json

echo "[6] Write activation evidence"
mkdir -p "$(dirname "$RESULT_FILE")" 2>/dev/null || true
jq -n --arg clientId "$CLIENT_ID" --arg principalId "$PRINCIPAL_ID" --arg tenantId "$TENANT_ID" --arg subscriptionId "$SUBSCRIPTION_ID" --arg resourceId "$IDENTITY_ID" --arg subject "$SUBJECT" --arg aksScope "$AKS_ID" --arg namespaceScope "$TEST_NAMESPACE_SCOPE" --arg acrScope "$ACR_ID" '{apiVersion:"platform.activation/v1",kind:"IdentityActivationResult",metadata:{environment:"test",identity:"k3s-gitops-test-uami"},spec:{githubOidc:{principalType:"UserAssignedManagedIdentity",clientId:$clientId,principalId:$principalId,tenantId:$tenantId,subscriptionId:$subscriptionId,resourceId:$resourceId,federatedSubject:$subject},roleAssignments:[{role:"Reader",scope:$aksScope},{role:"Azure Kubernetes Service Cluster User Role",scope:$aksScope},{role:"Azure Kubernetes Service RBAC Reader",scope:$namespaceScope},{role:"AcrPull",scope:$acrScope}]}}' > "$RESULT_FILE" || { echo "Failed to write result file: $RESULT_FILE" >&2; exit 1; }

if [[ ! -s "$RESULT_FILE" ]]; then
  echo "Result file was not created: $RESULT_FILE" >&2
  exit 1
fi

echo "========================================="
echo " TEST IDENTITY ACTIVATED"
echo "========================================="
echo "clientId=${CLIENT_ID}"
echo "principalId=${PRINCIPAL_ID}"
echo "tenantId=${TENANT_ID}"
echo "subscriptionId=${SUBSCRIPTION_ID}"
echo "resourceId=${IDENTITY_ID}"
echo "federatedSubject=${SUBJECT}"
echo "resultFile=${RESULT_FILE}"
echo "terminal remains open"
