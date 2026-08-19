#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT=""
APPLY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --environment) ENVIRONMENT="${2:-}"; shift 2 ;;
    --apply) APPLY=1; shift ;;
    *) echo "usage: $0 --environment dev|test|prod [--apply]" >&2; exit 2 ;;
  esac
done
[[ "$ENVIRONMENT" =~ ^(dev|test|prod)$ ]] || { echo "--environment must be dev, test or prod" >&2; exit 2; }

SUBSCRIPTION_ID="c12c3a36-99d8-4741-bcef-cd7df5d5cd4a"
TENANT_ID="a1c6a587-dc3b-40a5-9438-445d896bb5f2"
LOCATION="eastus"
REPOSITORY="iwacollection/k3s-gitops"
STATE_RG="rg-platform-cicd"
STATE_STORAGE="sttfstatec12c3a3699d8"
STATE_CONTAINER="tfstate"
ISSUER="https://token.actions.githubusercontent.com"
AUDIENCE="api://AzureADTokenExchange"

ENV_UPPER="$(printf '%s' "$ENVIRONMENT" | tr '[:lower:]' '[:upper:]')"
IDENTITY_NAME="k3s-gitops-iac-foundation-apply-${ENVIRONMENT}-uami"
GITHUB_ENVIRONMENT="iac-${ENVIRONMENT}-foundation-apply"
FIC_NAME="github-iac-${ENVIRONMENT}-foundation-apply"
ROLE_NAME="Enterprise IaC Platform Foundation ${ENV_UPPER} Apply"
STORAGE_BLOB_DATA_CONTRIBUTOR_ROLE_ID="ba92f5b4-2d11-453d-a403-e96b0029c9fe"

read -r ROLE_ID ROLE_ASSIGNMENT_ID STATE_ASSIGNMENT_ID < <(
python3 - "$ENVIRONMENT" <<'PY'
import sys, uuid
env=sys.argv[1]
ns=uuid.UUID('1c73e312-8bd0-4c2c-b234-9261d50b80c2')
for value in (f'foundation-role:{env}', f'foundation-role-assignment:{env}', f'foundation-state-assignment:{env}'):
    print(uuid.uuid5(ns, value), end=' ')
print()
PY
)

SUB_SCOPE="/subscriptions/${SUBSCRIPTION_ID}"
STATE_RG_SCOPE="${SUB_SCOPE}/resourceGroups/${STATE_RG}"
STATE_STORAGE_SCOPE="${STATE_RG_SCOPE}/providers/Microsoft.Storage/storageAccounts/${STATE_STORAGE}"
STATE_CONTAINER_SCOPE="${STATE_STORAGE_SCOPE}/blobServices/default/containers/${STATE_CONTAINER}"
ROLE_DEFINITION_ID="${SUB_SCOPE}/providers/Microsoft.Authorization/roleDefinitions/${ROLE_ID}"
RESULT_FILE="${ENVIRONMENT}-iac-platform-foundation-capability-result.json"

log(){ printf '[iac-foundation-%s] %s\n' "$ENVIRONMENT" "$*"; }
fail(){ printf '[iac-foundation-%s][ERROR] %s\n' "$ENVIRONMENT" "$*" >&2; exit 1; }
arm(){ printf 'https://management.azure.com%s' "$1"; }
put_json(){ az rest --method put --url "$(arm "$1?api-version=$2")" --headers 'Content-Type=application/json' --body "$3" --output none; }
identity_field(){ az rest --method get --url "$(arm "${STATE_RG_SCOPE}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${IDENTITY_NAME}?api-version=2023-01-31")" --query "properties.$1" -o tsv; }

command -v az >/dev/null || fail "Azure CLI is required"
command -v python3 >/dev/null || fail "python3 is required"
az account show >/dev/null 2>&1 || fail "Azure CLI is not authenticated"
[[ "$(az account show --query tenantId -o tsv)" == "$TENANT_ID" ]] || fail "unexpected tenant"
az account set --subscription "$SUBSCRIPTION_ID"

ROLE_BODY="$(cat <<EOF
{
  "properties": {
    "roleName": "${ROLE_NAME}",
    "description": "Platform foundation IaC role for environment VNet/Subnets, Private DNS zones/links, Log Analytics and Azure Monitor Workspace. No NAT, Public IP, LB, VPN, workload services, credentials or RBAC writes.",
    "type": "CustomRole",
    "permissions": [{
      "actions": [
        "Microsoft.Authorization/*/read",
        "Microsoft.Resources/subscriptions/read",
        "Microsoft.Resources/subscriptions/locations/read",
        "Microsoft.Resources/subscriptions/providers/read",
        "Microsoft.Resources/subscriptions/resourceGroups/read",
        "Microsoft.Resources/subscriptions/resourceGroups/write",
        "Microsoft.Resources/subscriptions/resourceGroups/delete",

        "Microsoft.Network/virtualNetworks/read",
        "Microsoft.Network/virtualNetworks/write",
        "Microsoft.Network/virtualNetworks/delete",
        "Microsoft.Network/virtualNetworks/join/action",
        "Microsoft.Network/virtualNetworks/subnets/read",
        "Microsoft.Network/virtualNetworks/subnets/write",
        "Microsoft.Network/virtualNetworks/subnets/delete",
        "Microsoft.Network/privateDnsZones/read",
        "Microsoft.Network/privateDnsZones/write",
        "Microsoft.Network/privateDnsZones/delete",
        "Microsoft.Network/privateDnsZones/virtualNetworkLinks/read",
        "Microsoft.Network/privateDnsZones/virtualNetworkLinks/write",
        "Microsoft.Network/privateDnsZones/virtualNetworkLinks/delete",
        "Microsoft.Network/privateDnsOperationResults/read",
        "Microsoft.Network/privateDnsOperationStatuses/read",
        "Microsoft.Network/locations/operations/read",
        "Microsoft.Network/locations/operationResults/read",

        "Microsoft.OperationalInsights/operations/read",
        "Microsoft.OperationalInsights/locations/operationstatuses/read",
        "Microsoft.OperationalInsights/workspaces/read",
        "Microsoft.OperationalInsights/workspaces/write",
        "Microsoft.OperationalInsights/workspaces/delete",
        "Microsoft.OperationalInsights/workspaces/operations/read",

        "Microsoft.Monitor/operations/read",
        "Microsoft.Monitor/locations/operationStatuses/read",
        "Microsoft.Monitor/accounts/read",
        "Microsoft.Monitor/accounts/write",
        "Microsoft.Monitor/accounts/delete"
      ],
      "notActions": [], "dataActions": [], "notDataActions": []
    }],
    "assignableScopes": ["${SUB_SCOPE}"]
  }
}
EOF
)"

python3 - "$ROLE_BODY" <<'PY'
import json, sys
a=set(json.loads(sys.argv[1])['properties']['permissions'][0]['actions'])
required={
 'Microsoft.Network/virtualNetworks/write',
 'Microsoft.Network/virtualNetworks/subnets/write',
 'Microsoft.Network/privateDnsZones/write',
 'Microsoft.Network/privateDnsZones/virtualNetworkLinks/write',
 'Microsoft.OperationalInsights/workspaces/write',
 'Microsoft.Monitor/accounts/write',
}
assert required <= a, required-a
forbidden_fragments=(
 'roleAssignments/write','publicIPAddresses/','natGateways/','loadBalancers/',
 'virtualNetworkGateways/','applicationGateways/','privateEndpoints/write',
 'storageAccounts/write','vaults/write','namespaces/write','redisEnterprise/write','flexibleServers/write'
)
for action in a:
    assert all(fragment not in action for fragment in forbidden_fragments), action
print('Platform foundation custom-role contract valid.')
PY

log "Identity: ${IDENTITY_NAME} -> ${GITHUB_ENVIRONMENT}"
log "Role: ${ROLE_NAME} (${ROLE_ID})"
if [[ "$APPLY" -eq 0 ]]; then
  cat <<EOF
PLAN ONLY - no Azure mutation.
Planned mutations:
  1. Create/normalize dedicated ${ENV_UPPER} Platform Foundation Apply UAMI + OIDC FIC.
  2. Create/update narrow VNet/Subnet + Private DNS + Observability custom role.
  3. Assign role at subscription scope and Blob Data Contributor only on tfstate container.
Explicitly not granted: Public IP, NAT, LB, VPN, Application Gateway, Private Endpoint creation, workload service writes, credential reads or RBAC writes.
EOF
  exit 0
fi

log "Registering required resource providers"
for provider in Microsoft.ManagedIdentity Microsoft.Network Microsoft.OperationalInsights Microsoft.Monitor; do
  az provider register --namespace "$provider" --wait --output none
 done

IDENTITY_BODY="$(printf '{"location":"%s","tags":{"managed_by":"iac-control-plane-bootstrap","environment":"%s","capability":"platform-foundation"}}' "$LOCATION" "$ENVIRONMENT")"
put_json "${STATE_RG_SCOPE}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${IDENTITY_NAME}" "2023-01-31" "$IDENTITY_BODY"
CLIENT_ID="$(identity_field clientId)"
PRINCIPAL_ID="$(identity_field principalId)"
[[ -n "$CLIENT_ID" && -n "$PRINCIPAL_ID" ]] || fail "failed to resolve Foundation Apply UAMI IDs"

FIC_BODY="$(printf '{"properties":{"issuer":"%s","subject":"repo:%s:environment:%s","audiences":["%s"]}}' "$ISSUER" "$REPOSITORY" "$GITHUB_ENVIRONMENT" "$AUDIENCE")"
put_json "${STATE_RG_SCOPE}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${IDENTITY_NAME}/federatedIdentityCredentials/${FIC_NAME}" "2024-11-30" "$FIC_BODY"
put_json "${SUB_SCOPE}/providers/Microsoft.Authorization/roleDefinitions/${ROLE_ID}" "2022-04-01" "$ROLE_BODY"
ASSIGN_BODY="$(printf '{"properties":{"principalId":"%s","principalType":"ServicePrincipal","roleDefinitionId":"%s"}}' "$PRINCIPAL_ID" "$ROLE_DEFINITION_ID")"
put_json "${SUB_SCOPE}/providers/Microsoft.Authorization/roleAssignments/${ROLE_ASSIGNMENT_ID}" "2022-04-01" "$ASSIGN_BODY"
STATE_ROLE_DEF="${SUB_SCOPE}/providers/Microsoft.Authorization/roleDefinitions/${STORAGE_BLOB_DATA_CONTRIBUTOR_ROLE_ID}"
STATE_BODY="$(printf '{"properties":{"principalId":"%s","principalType":"ServicePrincipal","roleDefinitionId":"%s"}}' "$PRINCIPAL_ID" "$STATE_ROLE_DEF")"
put_json "${STATE_CONTAINER_SCOPE}/providers/Microsoft.Authorization/roleAssignments/${STATE_ASSIGNMENT_ID}" "2022-04-01" "$STATE_BODY"

cat > "$RESULT_FILE" <<EOF
{
  "status": "READY_FOR_IAC_PLATFORM_FOUNDATION_GITHUB_BINDING",
  "environment": "${ENVIRONMENT}",
  "githubEnvironment": "${GITHUB_ENVIRONMENT}",
  "identityName": "${IDENTITY_NAME}",
  "clientId": "${CLIENT_ID}",
  "principalId": "${PRINCIPAL_ID}",
  "resourceId": "${STATE_RG_SCOPE}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${IDENTITY_NAME}",
  "roleName": "${ROLE_NAME}",
  "roleId": "${ROLE_ID}",
  "roleAssignmentId": "${ROLE_ASSIGNMENT_ID}",
  "stateRole": "Storage Blob Data Contributor",
  "stateScope": "container",
  "publicIpWrite": false,
  "natGatewayWrite": false,
  "loadBalancerWrite": false,
  "vpnGatewayWrite": false,
  "privateEndpointWrite": false,
  "workloadServiceWrite": false,
  "roleAssignmentWrite": false
}
EOF
python3 -m json.tool "$RESULT_FILE" >/dev/null
log "Platform foundation capability activation complete: $RESULT_FILE"
