#!/usr/bin/env bash
set -euo pipefail

# One-time privileged activation for the logical PROD verification boundary.
# Default: PLAN ONLY. Pass --apply to mutate Azure.

APPLY=0
if [[ "${1:-}" == "--apply" ]]; then
  APPLY=1
elif [[ -n "${1:-}" ]]; then
  echo "usage: $0 [--apply]" >&2
  exit 2
fi

SUBSCRIPTION_ID="c12c3a36-99d8-4741-bcef-cd7df5d5cd4a"
TENANT_ID="a1c6a587-dc3b-40a5-9438-445d896bb5f2"
RESOURCE_GROUP="group-test"
LOCATION="eastus"
AKS_NAME="k8s-test-cicd"
ACR_NAME="acrcicdc12c3a3699d8"
PROD_NAMESPACE="cicd-prod"
IDENTITY_NAME="k3s-gitops-prod-uami"
GITHUB_ENVIRONMENT="prod"
FIC_NAME="github-prod-observer"
OIDC_SUBJECT="repo:iwacollection/k3s-gitops:environment:prod"
RESULT_FILE="prod-identity-activation-result.json"

READER_ROLE_ID="acdd72a7-3385-48ef-bd42-f606fba81ae7"
AKS_CLUSTER_USER_ROLE_ID="4abbcc35-e782-43d8-92c5-2d3f1bd2253f"
ACR_PULL_ROLE_ID="7f951dda-4ed3-4680-a7ca-43fe172d538d"
CUSTOM_ROLE_NAME="k3s-gitops-prod-observer"
CUSTOM_ROLE_ID="f39bf173-72d0-5d91-a684-8da60f857e1b"

SUB_SCOPE="/subscriptions/${SUBSCRIPTION_ID}"
RG_SCOPE="${SUB_SCOPE}/resourceGroups/${RESOURCE_GROUP}"
AKS_SCOPE="${RG_SCOPE}/providers/Microsoft.ContainerService/managedClusters/${AKS_NAME}"
ACR_SCOPE="${RG_SCOPE}/providers/Microsoft.ContainerRegistry/registries/${ACR_NAME}"
IDENTITY_ID="${RG_SCOPE}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${IDENTITY_NAME}"
CUSTOM_ROLE_DEF_ID="${SUB_SCOPE}/providers/Microsoft.Authorization/roleDefinitions/${CUSTOM_ROLE_ID}"

log() { printf '[prod-identity] %s\n' "$*"; }
fail() { printf '[prod-identity][ERROR] %s\n' "$*" >&2; exit 1; }
arm_url() { printf 'https://management.azure.com%s' "$1"; }
role_definition_id() { printf '%s/providers/Microsoft.Authorization/roleDefinitions/%s' "$SUB_SCOPE" "$1"; }

put_role_assignment() {
  local scope="$1" assignment_id="$2" role_definition_id="$3" principal_id="$4"
  local body
  body="$(cat <<EOF
{
  "properties": {
    "principalId": "${principal_id}",
    "principalType": "ServicePrincipal",
    "roleDefinitionId": "${role_definition_id}"
  }
}
EOF
)"
  az rest --method put \
    --url "$(arm_url "${scope}/providers/Microsoft.Authorization/roleAssignments/${assignment_id}?api-version=2022-04-01")" \
    --headers 'Content-Type=application/json' \
    --body "$body" \
    --output none
}

command -v az >/dev/null 2>&1 || fail "Azure CLI is required"
command -v python3 >/dev/null 2>&1 || fail "python3 is required"
az account show >/dev/null 2>&1 || fail "Azure CLI is not authenticated"
[[ "$(az account show --query tenantId -o tsv)" == "$TENANT_ID" ]] || fail "unexpected Azure tenant"
az account set --subscription "$SUBSCRIPTION_ID"
[[ "$(az account show --query id -o tsv)" == "$SUBSCRIPTION_ID" ]] || fail "unexpected Azure subscription"

ROLE_BODY="$(cat <<EOF
{
  "properties": {
    "roleName": "${CUSTOM_ROLE_NAME}",
    "description": "Read-only Kubernetes observation role restricted to the logical PROD namespace.",
    "type": "CustomRole",
    "permissions": [
      {
        "actions": [
          "Microsoft.ContainerService/managedClusters/read",
          "Microsoft.ContainerService/managedClusters/listClusterUserCredential/action"
        ],
        "notActions": [],
        "dataActions": [
          "Microsoft.ContainerService/managedClusters/apps/deployments/read",
          "Microsoft.ContainerService/managedClusters/apps/replicasets/read",
          "Microsoft.ContainerService/managedClusters/core/pods/read",
          "Microsoft.ContainerService/managedClusters/core/services/read",
          "Microsoft.ContainerService/managedClusters/discovery.k8s.io/endpointslices/read"
        ],
        "notDataActions": []
      }
    ],
    "assignableScopes": ["${SUB_SCOPE}"]
  }
}
EOF
)"

python3 - "$ROLE_BODY" <<'PY'
import json, sys
body=json.loads(sys.argv[1])
perm=body['properties']['permissions'][0]
actions=set(perm['actions']); data=set(perm['dataActions'])
forbidden=('write','delete','create','patch','update','roleassignments')
for action in actions | data:
    lowered=action.lower()
    if any(word in lowered for word in forbidden):
        raise SystemExit(f'forbidden mutation action in PROD observer role: {action}')
print('PROD observer custom-role contract valid.')
PY

log "Target subscription: $SUBSCRIPTION_ID"
log "Shared AKS: $RESOURCE_GROUP / $AKS_NAME"
log "PROD namespace: $PROD_NAMESPACE"
log "Identity: $IDENTITY_NAME -> GitHub environment $GITHUB_ENVIRONMENT"

if [[ "$APPLY" -eq 0 ]]; then
  log "PLAN ONLY - no Azure mutation will be performed"
  cat <<EOF

Planned Azure mutations:
  1. Create/normalize UAMI ${IDENTITY_NAME} in ${RESOURCE_GROUP}
  2. Add GitHub OIDC FIC subject ${OIDC_SUBJECT}
  3. Create/update narrow read-only custom role ${CUSTOM_ROLE_NAME}
  4. Reader on AKS resource only
  5. AKS Cluster User on AKS resource only
  6. ${CUSTOM_ROLE_NAME} only at namespace scope ${PROD_NAMESPACE}
  7. AcrPull only on ${ACR_NAME}

Explicitly not granted: Owner, Contributor, User Access Administrator, resource-group Reader, AKS RBAC Writer/Admin, AcrPush, Deployment write.
Run with mutations enabled:
  $0 --apply
EOF
  exit 0
fi

log "Verifying bootstrap operator can manage role definitions and assignments"
az rest --method get --url "$(arm_url "${SUB_SCOPE}/providers/Microsoft.Authorization/roleDefinitions?api-version=2022-04-01&%24filter=roleName%20eq%20'Owner'")" --output none

log "Creating/normalizing PROD UAMI"
IDENTITY_BODY="$(cat <<EOF
{
  "location": "${LOCATION}",
  "tags": {
    "managed_by": "enterprise-cicd-activation",
    "environment": "prod",
    "purpose": "github-oidc-read-verification"
  }
}
EOF
)"
az rest --method put \
  --url "$(arm_url "${IDENTITY_ID}?api-version=2023-01-31")" \
  --headers 'Content-Type=application/json' \
  --body "$IDENTITY_BODY" \
  --output none

PROD_CLIENT_ID="$(az rest --method get --url "$(arm_url "${IDENTITY_ID}?api-version=2023-01-31")" --query properties.clientId -o tsv)"
PROD_PRINCIPAL_ID="$(az rest --method get --url "$(arm_url "${IDENTITY_ID}?api-version=2023-01-31")" --query properties.principalId -o tsv)"
[[ -n "$PROD_CLIENT_ID" && -n "$PROD_PRINCIPAL_ID" ]] || fail "failed to resolve PROD UAMI IDs"

log "Creating/normalizing PROD GitHub federated credential"
FIC_BODY="$(cat <<EOF
{
  "properties": {
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "${OIDC_SUBJECT}",
    "audiences": ["api://AzureADTokenExchange"]
  }
}
EOF
)"
az rest --method put \
  --url "$(arm_url "${IDENTITY_ID}/federatedIdentityCredentials/${FIC_NAME}?api-version=2023-01-31")" \
  --headers 'Content-Type=application/json' \
  --body "$FIC_BODY" \
  --output none

log "Creating/updating narrow namespace observer role"
az rest --method put \
  --url "$(arm_url "${CUSTOM_ROLE_DEF_ID}?api-version=2022-04-01")" \
  --headers 'Content-Type=application/json' \
  --body "$ROLE_BODY" \
  --output none

NAMESPACE_SCOPE="${AKS_SCOPE}/namespaces/${PROD_NAMESPACE}"
log "Assigning read-only Azure/AKS/ACR roles"
put_role_assignment "$AKS_SCOPE" "33c3a3c0-84e8-5d77-80c3-02b3d97d10df" "$(role_definition_id "$READER_ROLE_ID")" "$PROD_PRINCIPAL_ID"
put_role_assignment "$AKS_SCOPE" "c026e981-0d13-582f-bbc8-55a2b5a10c31" "$(role_definition_id "$AKS_CLUSTER_USER_ROLE_ID")" "$PROD_PRINCIPAL_ID"
put_role_assignment "$NAMESPACE_SCOPE" "84ed4b36-abcc-55f1-95b8-0ca984eb45de" "$CUSTOM_ROLE_DEF_ID" "$PROD_PRINCIPAL_ID"
put_role_assignment "$ACR_SCOPE" "23db447a-3b56-5d78-a72c-6163c6502395" "$(role_definition_id "$ACR_PULL_ROLE_ID")" "$PROD_PRINCIPAL_ID"

cat > "$RESULT_FILE" <<EOF
{
  "status": "READY_FOR_PROD_GITHUB_BINDING",
  "environment": "prod",
  "subscriptionId": "${SUBSCRIPTION_ID}",
  "tenantId": "${TENANT_ID}",
  "resourceGroup": "${RESOURCE_GROUP}",
  "cluster": "${AKS_NAME}",
  "namespace": "${PROD_NAMESPACE}",
  "acr": "${ACR_NAME}",
  "githubEnvironment": "${GITHUB_ENVIRONMENT}",
  "identityName": "${IDENTITY_NAME}",
  "clientId": "${PROD_CLIENT_ID}",
  "principalId": "${PROD_PRINCIPAL_ID}",
  "resourceId": "${IDENTITY_ID}",
  "federatedCredential": "${FIC_NAME}",
  "subject": "${OIDC_SUBJECT}",
  "customRoleName": "${CUSTOM_ROLE_NAME}",
  "customRoleId": "${CUSTOM_ROLE_ID}",
  "resourceGroupReader": false,
  "acrPush": false,
  "deploymentWrite": false
}
EOF

python3 -m json.tool "$RESULT_FILE"
log "PROD identity activation complete; commit the non-secret binding before enabling PROD verification workflows"
