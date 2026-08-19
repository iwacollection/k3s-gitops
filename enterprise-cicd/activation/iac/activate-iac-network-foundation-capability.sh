#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT=""
APPLY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --environment) ENVIRONMENT="${2:-}"; shift 2 ;;
    --apply) APPLY=1; shift ;;
    *) echo "usage: $0 --environment test|prod [--apply]" >&2; exit 2 ;;
  esac
done
[[ "$ENVIRONMENT" == "test" || "$ENVIRONMENT" == "prod" ]] || { echo "--environment must be test or prod; DEV is already activated by activate-dev-network-capability.sh" >&2; exit 2; }

SUBSCRIPTION_ID="c12c3a36-99d8-4741-bcef-cd7df5d5cd4a"
TENANT_ID="a1c6a587-dc3b-40a5-9438-445d896bb5f2"
STATE_RG="rg-platform-cicd"
APPLY_IDENTITY_NAME="k3s-gitops-iac-apply-${ENVIRONMENT}-uami"
ENV_UPPER="$(printf '%s' "$ENVIRONMENT" | tr '[:lower:]' '[:upper:]')"
ROLE_NAME="Enterprise IaC Network Foundation ${ENV_UPPER} Apply"
NETWORK_CONTRIBUTOR_ROLE_ID="4d97b98b-1d4f-4787-a291-c67834d212e7"

read -r ROLE_ID ROLE_ASSIGNMENT_ID < <(
python3 - "$ENVIRONMENT" <<'PY'
import sys, uuid
env=sys.argv[1]
ns=uuid.UUID('f2509f06-e507-4014-99cb-07368cb41ea2')
for value in (f'network-foundation-role:{env}', f'network-foundation-assignment:{env}'):
    print(uuid.uuid5(ns, value), end=' ')
print()
PY
)

SUB_SCOPE="/subscriptions/${SUBSCRIPTION_ID}"
STATE_RG_SCOPE="${SUB_SCOPE}/resourceGroups/${STATE_RG}"
IDENTITY_SCOPE="${STATE_RG_SCOPE}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${APPLY_IDENTITY_NAME}"
ROLE_DEFINITION_ID="${SUB_SCOPE}/providers/Microsoft.Authorization/roleDefinitions/${ROLE_ID}"
RESULT_FILE="${ENVIRONMENT}-iac-network-foundation-capability-result.json"

log(){ printf '[iac-network-foundation-%s] %s\n' "$ENVIRONMENT" "$*"; }
fail(){ printf '[iac-network-foundation-%s][ERROR] %s\n' "$ENVIRONMENT" "$*" >&2; exit 1; }
arm(){ printf 'https://management.azure.com%s' "$1"; }

command -v az >/dev/null 2>&1 || fail "Azure CLI is required"
command -v python3 >/dev/null 2>&1 || fail "python3 is required"
az account show >/dev/null 2>&1 || fail "Azure CLI is not authenticated"
[[ "$(az account show --query tenantId -o tsv)" == "$TENANT_ID" ]] || fail "unexpected tenant"
az account set --subscription "$SUBSCRIPTION_ID"

APPLY_PRINCIPAL_ID="$(az rest --method get --url "$(arm "${IDENTITY_SCOPE}?api-version=2023-01-31")" --query properties.principalId -o tsv 2>/dev/null || true)"
[[ -n "$APPLY_PRINCIPAL_ID" ]] || fail "base ${ENV_UPPER} Apply UAMI is not activated; run bootstrap-iac-environment.sh --environment ${ENVIRONMENT} --apply first"

ROLE_BODY="$(cat <<EOF
{
  "properties": {
    "roleName": "${ROLE_NAME}",
    "description": "${ENV_UPPER} standard IaC capability limited to VNet and Subnet lifecycle. No Public IP, NAT, Peering, VPN, Load Balancer, Application Gateway, DNS or RBAC writes.",
    "type": "CustomRole",
    "permissions": [{
      "actions": [
        "Microsoft.Authorization/*/read",
        "Microsoft.Resources/subscriptions/read",
        "Microsoft.Resources/subscriptions/locations/read",
        "Microsoft.Resources/subscriptions/providers/read",
        "Microsoft.Resources/subscriptions/resourceGroups/read",
        "Microsoft.Network/locations/operations/read",
        "Microsoft.Network/locations/operationResults/read",
        "Microsoft.Network/locations/usages/read",
        "Microsoft.Network/virtualNetworks/read",
        "Microsoft.Network/virtualNetworks/write",
        "Microsoft.Network/virtualNetworks/delete",
        "Microsoft.Network/virtualNetworks/usages/read",
        "Microsoft.Network/virtualNetworks/subnets/read",
        "Microsoft.Network/virtualNetworks/subnets/write",
        "Microsoft.Network/virtualNetworks/subnets/delete",
        "Microsoft.Network/virtualNetworks/subnets/join/action"
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
for required in ('Microsoft.Network/virtualNetworks/write','Microsoft.Network/virtualNetworks/subnets/write','Microsoft.Network/locations/operationResults/read'):
    assert required in a
for forbidden in ('Microsoft.Network/*','publicIPAddresses','natGateways','virtualNetworkPeerings','loadBalancers','virtualNetworkGateways','applicationGateways','privateDnsZones','Microsoft.Authorization/roleAssignments/write'):
    assert not any(forbidden in action for action in a), forbidden
print('Network foundation role contract valid.')
PY

log "Target base Apply UAMI: ${APPLY_IDENTITY_NAME} (${APPLY_PRINCIPAL_ID})"
log "Role: ${ROLE_NAME} (${ROLE_ID})"
if [[ "$APPLY" -eq 0 ]]; then
  cat <<EOF
PLAN ONLY - no Azure mutation.
Planned mutations:
  1. Register Microsoft.Network if needed.
  2. Create/update VNet/Subnet-only custom role.
  3. Assign it to the existing ${ENV_UPPER} standard Apply UAMI.
Explicitly not granted: Network Contributor (${NETWORK_CONTRIBUTOR_ROLE_ID}), Public IP, NAT Gateway, Peering, Load Balancer, VPN Gateway, Application Gateway, Private DNS or RBAC write.
EOF
  exit 0
fi

az provider register --namespace Microsoft.Network --wait --output none
az rest --method put --url "$(arm "${ROLE_DEFINITION_ID}?api-version=2022-04-01")" --headers 'Content-Type=application/json' --body "$ROLE_BODY" --output none
ASSIGN_BODY="$(printf '{"properties":{"principalId":"%s","principalType":"ServicePrincipal","roleDefinitionId":"%s"}}' "$APPLY_PRINCIPAL_ID" "$ROLE_DEFINITION_ID")"
az rest --method put --url "$(arm "${SUB_SCOPE}/providers/Microsoft.Authorization/roleAssignments/${ROLE_ASSIGNMENT_ID}?api-version=2022-04-01")" --headers 'Content-Type=application/json' --body "$ASSIGN_BODY" --output none

cat > "$RESULT_FILE" <<EOF
{
  "status": "READY_FOR_IAC_NETWORK_FOUNDATION_APPLY",
  "environment": "${ENVIRONMENT}",
  "applyIdentityName": "${APPLY_IDENTITY_NAME}",
  "applyPrincipalId": "${APPLY_PRINCIPAL_ID}",
  "roleName": "${ROLE_NAME}",
  "roleId": "${ROLE_ID}",
  "roleAssignmentId": "${ROLE_ASSIGNMENT_ID}",
  "genericNetworkContributor": false,
  "publicIpWrite": false,
  "natGatewayWrite": false,
  "peeringWrite": false,
  "loadBalancerWrite": false,
  "vpnGatewayWrite": false,
  "applicationGatewayWrite": false,
  "roleAssignmentWrite": false
}
EOF
python3 -m json.tool "$RESULT_FILE" >/dev/null
log "Network foundation activation complete: $RESULT_FILE"
