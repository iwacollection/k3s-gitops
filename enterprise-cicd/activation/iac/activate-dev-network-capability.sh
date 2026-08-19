#!/usr/bin/env bash
set -euo pipefail

# One-time privileged activation for the DEV IaC network capability.
# Default: PLAN ONLY. Pass --apply to create/update the narrow custom role
# and assign it to the existing dedicated DEV Apply UAMI.

APPLY=0
if [[ "${1:-}" == "--apply" ]]; then
  APPLY=1
elif [[ -n "${1:-}" ]]; then
  echo "usage: $0 [--apply]" >&2
  exit 2
fi

SUBSCRIPTION_ID="c12c3a36-99d8-4741-bcef-cd7df5d5cd4a"
TENANT_ID="a1c6a587-dc3b-40a5-9438-445d896bb5f2"
APPLY_PRINCIPAL_ID="d71f3fb7-b6ab-41f8-a48e-1970ee182c06"

ROLE_NAME="Enterprise IaC Network DEV Apply"
ROLE_ID="3f038234-66c3-5cb3-b9e9-5297931c9692"
ROLE_ASSIGNMENT_ID="ba04be55-341b-5828-b32b-1be9e06f90f4"
NETWORK_CONTRIBUTOR_ROLE_ID="4d97b98b-1d4f-4787-a291-c67834d212e7"

SUB_SCOPE="/subscriptions/${SUBSCRIPTION_ID}"
ROLE_DEFINITION_ID="${SUB_SCOPE}/providers/Microsoft.Authorization/roleDefinitions/${ROLE_ID}"
RESULT_FILE="dev-iac-network-capability-result.json"

log() {
  printf '[iac-network-capability] %s\n' "$*"
}

fail() {
  printf '[iac-network-capability][ERROR] %s\n' "$*" >&2
  exit 1
}

arm_url() {
  printf 'https://management.azure.com%s' "$1"
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
    "roleName": "${ROLE_NAME}",
    "description": "DEV IaC capability limited to Virtual Network and Subnet lifecycle. No Public IP, NAT Gateway, Peering, VPN, Application Gateway, DNS or RBAC writes.",
    "type": "CustomRole",
    "permissions": [
      {
        "actions": [
          "Microsoft.Authorization/*/read",
          "Microsoft.Resources/subscriptions/read",
          "Microsoft.Resources/subscriptions/locations/read",
          "Microsoft.Resources/subscriptions/providers/read",
          "Microsoft.Resources/subscriptions/resourceGroups/read",
          "Microsoft.Network/locations/operations/read",
          "Microsoft.Network/usages/read",
          "Microsoft.Network/virtualNetworks/read",
          "Microsoft.Network/virtualNetworks/write",
          "Microsoft.Network/virtualNetworks/delete",
          "Microsoft.Network/virtualNetworks/subnets/read",
          "Microsoft.Network/virtualNetworks/subnets/write",
          "Microsoft.Network/virtualNetworks/subnets/delete",
          "Microsoft.Network/virtualNetworks/subnets/join/action"
        ],
        "notActions": [],
        "dataActions": [],
        "notDataActions": []
      }
    ],
    "assignableScopes": ["${SUB_SCOPE}"]
  }
}
EOF
)"

python3 - "$ROLE_BODY" <<'PY'
import json
import sys
body = json.loads(sys.argv[1])
actions = set(body['properties']['permissions'][0]['actions'])
required = {
    'Microsoft.Network/virtualNetworks/read',
    'Microsoft.Network/virtualNetworks/write',
    'Microsoft.Network/virtualNetworks/delete',
    'Microsoft.Network/virtualNetworks/subnets/read',
    'Microsoft.Network/virtualNetworks/subnets/write',
    'Microsoft.Network/virtualNetworks/subnets/delete',
}
missing = required - actions
if missing:
    raise SystemExit(f'missing required network actions: {sorted(missing)}')
forbidden_fragments = (
    'Microsoft.Network/*',
    'publicIPAddresses',
    'natGateways',
    'virtualNetworkPeerings',
    'vpnGateways',
    'virtualNetworkGateways',
    'applicationGateways',
    'privateDnsZones',
)
for action in actions:
    if any(fragment in action for fragment in forbidden_fragments):
        raise SystemExit(f'forbidden broad or paid network capability: {action}')
print('Network custom-role contract valid.')
PY

log "Target Apply principal: $APPLY_PRINCIPAL_ID"
log "Role: $ROLE_NAME ($ROLE_ID)"
log "Scope: $SUB_SCOPE"

if [[ "$APPLY" -eq 0 ]]; then
  log "PLAN ONLY - no Azure mutation will be performed"
  printf '\nPlanned Azure mutations:\n'
  printf '  1. Ensure Microsoft.Network provider is registered\n'
  printf '  2. Create/update narrow custom role %s\n' "$ROLE_NAME"
  printf '  3. Assign that role to the existing DEV Apply UAMI at subscription scope\n'
  printf '\nExplicitly NOT granted: Network Contributor (%s), Microsoft.Network/*, Public IP, NAT Gateway, Peering, VPN, Application Gateway, Private DNS, RBAC write.\n' "$NETWORK_CONTRIBUTOR_ROLE_ID"
  printf 'Run with mutations enabled:\n  %s --apply\n' "$0"
  exit 0
fi

log "Registering Microsoft.Network provider"
az provider register --namespace Microsoft.Network --wait --output none

log "Creating/updating narrow network custom role"
az rest \
  --method put \
  --url "$(arm_url "${ROLE_DEFINITION_ID}?api-version=2022-04-01")" \
  --headers 'Content-Type=application/json' \
  --body "$ROLE_BODY" \
  --output none

ASSIGNMENT_BODY="$(cat <<EOF
{
  "properties": {
    "principalId": "${APPLY_PRINCIPAL_ID}",
    "principalType": "ServicePrincipal",
    "roleDefinitionId": "${ROLE_DEFINITION_ID}"
  }
}
EOF
)"

log "Assigning network capability to dedicated DEV Apply UAMI"
az rest \
  --method put \
  --url "$(arm_url "${SUB_SCOPE}/providers/Microsoft.Authorization/roleAssignments/${ROLE_ASSIGNMENT_ID}?api-version=2022-04-01")" \
  --headers 'Content-Type=application/json' \
  --body "$ASSIGNMENT_BODY" \
  --output none

log "Verifying effective role definition contract"
az rest \
  --method get \
  --url "$(arm_url "${ROLE_DEFINITION_ID}?api-version=2022-04-01")" \
  --output json > /tmp/dev-iac-network-role.json

python3 - /tmp/dev-iac-network-role.json <<'PY'
import json
import sys
role = json.load(open(sys.argv[1]))
actions = set(role['properties']['permissions'][0]['actions'])
assert 'Microsoft.Network/virtualNetworks/write' in actions
assert 'Microsoft.Network/virtualNetworks/subnets/write' in actions
assert 'Microsoft.Network/*' not in actions
for forbidden in ('publicIPAddresses', 'natGateways', 'virtualNetworkPeerings', 'vpnGateways', 'virtualNetworkGateways', 'applicationGateways', 'privateDnsZones'):
    assert not any(forbidden in action for action in actions), forbidden
print('Effective Azure network role is narrow and valid.')
PY

cat > "$RESULT_FILE" <<EOF
{
  "status": "READY_FOR_DEV_NETWORK_APPLY",
  "subscriptionId": "${SUBSCRIPTION_ID}",
  "applyPrincipalId": "${APPLY_PRINCIPAL_ID}",
  "roleName": "${ROLE_NAME}",
  "roleId": "${ROLE_ID}",
  "roleAssignmentId": "${ROLE_ASSIGNMENT_ID}",
  "scope": "${SUB_SCOPE}",
  "genericNetworkContributor": false,
  "publicIpWrite": false,
  "natGatewayWrite": false,
  "peeringWrite": false,
  "vpnGatewayWrite": false,
  "applicationGatewayWrite": false,
  "roleAssignmentWrite": false
}
EOF

python3 -m json.tool "$RESULT_FILE"
log "Network capability activation complete"
