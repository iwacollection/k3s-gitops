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
IDENTITY_NAME="k3s-gitops-iac-edge-apply-${ENVIRONMENT}-uami"
GITHUB_ENVIRONMENT="iac-${ENVIRONMENT}-edge-apply"
FIC_NAME="github-iac-${ENVIRONMENT}-edge-apply"
ROLE_NAME="Enterprise IaC Edge Network ${ENV_UPPER} Apply"
STORAGE_BLOB_DATA_CONTRIBUTOR_ROLE_ID="ba92f5b4-2d11-453d-a403-e96b0029c9fe"
NETWORK_CONTRIBUTOR_ROLE_ID="4d97b98b-1d4f-4787-a291-c67834d212e7"

read -r ROLE_ID ROLE_ASSIGNMENT_ID STATE_ASSIGNMENT_ID < <(
python3 - "$ENVIRONMENT" <<'PY'
import sys, uuid
env=sys.argv[1]
ns=uuid.UUID('7e74c563-24b7-41c1-86ae-44a7f991dce2')
for value in (f'edge-role:{env}', f'edge-role-assignment:{env}', f'edge-state-assignment:{env}'):
    print(uuid.uuid5(ns, value), end=' ')
print()
PY
)

SUB_SCOPE="/subscriptions/${SUBSCRIPTION_ID}"
STATE_RG_SCOPE="${SUB_SCOPE}/resourceGroups/${STATE_RG}"
STATE_STORAGE_SCOPE="${STATE_RG_SCOPE}/providers/Microsoft.Storage/storageAccounts/${STATE_STORAGE}"
STATE_CONTAINER_SCOPE="${STATE_STORAGE_SCOPE}/blobServices/default/containers/${STATE_CONTAINER}"
ROLE_DEFINITION_ID="${SUB_SCOPE}/providers/Microsoft.Authorization/roleDefinitions/${ROLE_ID}"
RESULT_FILE="${ENVIRONMENT}-iac-edge-capability-result.json"

log(){ printf '[iac-edge-%s] %s\n' "$ENVIRONMENT" "$*"; }
fail(){ printf '[iac-edge-%s][ERROR] %s\n' "$ENVIRONMENT" "$*" >&2; exit 1; }
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
    "description": "Protected Edge IaC role for VNet/Subnet, Standard Public IP, Standard Load Balancer and Virtual Network Gateway foundation. No peering, NAT Gateway, Application Gateway, VPN connection or RBAC writes.",
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
        "Microsoft.Network/virtualNetworks/subnets/read",
        "Microsoft.Network/virtualNetworks/subnets/write",
        "Microsoft.Network/virtualNetworks/subnets/delete",
        "Microsoft.Network/virtualNetworks/usages/read",
        "Microsoft.Network/publicIPAddresses/read",
        "Microsoft.Network/publicIPAddresses/write",
        "Microsoft.Network/publicIPAddresses/delete",
        "Microsoft.Network/loadBalancers/read",
        "Microsoft.Network/loadBalancers/write",
        "Microsoft.Network/loadBalancers/delete",
        "Microsoft.Network/loadBalancers/backendAddressPools/read",
        "Microsoft.Network/loadBalancers/backendAddressPools/write",
        "Microsoft.Network/loadBalancers/backendAddressPools/delete",
        "Microsoft.Network/loadBalancers/probes/read",
        "Microsoft.Network/loadBalancers/probes/write",
        "Microsoft.Network/loadBalancers/probes/delete",
        "Microsoft.Network/loadBalancers/loadBalancingRules/read",
        "Microsoft.Network/loadBalancers/loadBalancingRules/write",
        "Microsoft.Network/loadBalancers/loadBalancingRules/delete",
        "Microsoft.Network/virtualNetworkGateways/read",
        "Microsoft.Network/virtualNetworkGateways/write",
        "Microsoft.Network/virtualNetworkGateways/delete",
        "Microsoft.Network/locations/operations/read",
        "Microsoft.Network/locations/operationResults/read"
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
role=json.loads(sys.argv[1])
a=set(role['properties']['permissions'][0]['actions'])
required={
 'Microsoft.Network/publicIPAddresses/write',
 'Microsoft.Network/loadBalancers/write',
 'Microsoft.Network/loadBalancers/backendAddressPools/write',
 'Microsoft.Network/loadBalancers/probes/write',
 'Microsoft.Network/loadBalancers/loadBalancingRules/write',
 'Microsoft.Network/virtualNetworkGateways/write',
}
assert required <= a
forbidden=('Microsoft.Network/*','virtualNetworkPeerings/write','natGateways/write','applicationGateways/write','virtualNetworkGatewayConnections/write','Microsoft.Authorization/roleAssignments/write')
for item in forbidden:
    assert all(item not in action for action in a), item
print('Edge role contract valid.')
PY

log "Identity: ${IDENTITY_NAME} -> ${GITHUB_ENVIRONMENT}"
log "Role: ${ROLE_NAME} (${ROLE_ID})"
if [[ "$APPLY" -eq 0 ]]; then
  cat <<EOF
PLAN ONLY - no Azure mutation.
Planned mutations:
  1. Create/normalize dedicated ${ENV_UPPER} Edge Apply UAMI and OIDC FIC.
  2. Create/update narrow Edge network custom role.
  3. Assign Edge role at subscription scope and Blob Data Contributor only on tfstate container.
Explicitly not granted: Network Contributor (${NETWORK_CONTRIBUTOR_ROLE_ID}), Microsoft.Network/*, Peering, NAT Gateway, Application Gateway, Virtual Network Gateway Connection, RBAC write.
EOF
  exit 0
fi

log "Registering required providers"
az provider register --namespace Microsoft.ManagedIdentity --wait --output none
az provider register --namespace Microsoft.Network --wait --output none

IDENTITY_BODY="$(printf '{"location":"%s","tags":{"managed_by":"iac-control-plane-bootstrap","environment":"%s","capability":"edge-network"}}' "$LOCATION" "$ENVIRONMENT")"
put_json "${STATE_RG_SCOPE}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${IDENTITY_NAME}" "2023-01-31" "$IDENTITY_BODY"
CLIENT_ID="$(identity_field clientId)"
PRINCIPAL_ID="$(identity_field principalId)"
[[ -n "$CLIENT_ID" && -n "$PRINCIPAL_ID" ]] || fail "failed to resolve Edge UAMI IDs"

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
  "status": "READY_FOR_IAC_EDGE_GITHUB_BINDING",
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
  "genericNetworkContributor": false,
  "peeringWrite": false,
  "natGatewayWrite": false,
  "applicationGatewayWrite": false,
  "vpnConnectionWrite": false,
  "roleAssignmentWrite": false
}
EOF
python3 -m json.tool "$RESULT_FILE" >/dev/null
log "Edge capability activation complete: $RESULT_FILE"
