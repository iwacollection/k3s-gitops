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
IDENTITY_NAME="k3s-gitops-iac-workload-apply-${ENVIRONMENT}-uami"
GITHUB_ENVIRONMENT="iac-${ENVIRONMENT}-workload-apply"
FIC_NAME="github-iac-${ENVIRONMENT}-workload-apply"
ROLE_NAME="Enterprise IaC Workload Services ${ENV_UPPER} Apply"
STORAGE_BLOB_DATA_CONTRIBUTOR_ROLE_ID="ba92f5b4-2d11-453d-a403-e96b0029c9fe"

read -r ROLE_ID ROLE_ASSIGNMENT_ID STATE_ASSIGNMENT_ID < <(
python3 - "$ENVIRONMENT" <<'PY'
import sys, uuid
env=sys.argv[1]
ns=uuid.UUID('1f4db182-f6f8-43a9-b5f9-4f3951e3ee70')
for value in (f'workload-role:{env}', f'workload-role-assignment:{env}', f'workload-state-assignment:{env}'):
    print(uuid.uuid5(ns, value), end=' ')
print()
PY
)

SUB_SCOPE="/subscriptions/${SUBSCRIPTION_ID}"
STATE_RG_SCOPE="${SUB_SCOPE}/resourceGroups/${STATE_RG}"
STATE_STORAGE_SCOPE="${STATE_RG_SCOPE}/providers/Microsoft.Storage/storageAccounts/${STATE_STORAGE}"
STATE_CONTAINER_SCOPE="${STATE_STORAGE_SCOPE}/blobServices/default/containers/${STATE_CONTAINER}"
ROLE_DEFINITION_ID="${SUB_SCOPE}/providers/Microsoft.Authorization/roleDefinitions/${ROLE_ID}"
RESULT_FILE="${ENVIRONMENT}-iac-workload-capability-result.json"

log(){ printf '[iac-workload-%s] %s\n' "$ENVIRONMENT" "$*"; }
fail(){ printf '[iac-workload-%s][ERROR] %s\n' "$ENVIRONMENT" "$*" >&2; exit 1; }
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
    "description": "Protected workload IaC role for ACR, Storage, Key Vault, Service Bus, Azure Managed Redis, PostgreSQL Flexible Server, private endpoints, diagnostics and production locks. No data-plane secrets, credentials or RBAC writes.",
    "type": "CustomRole",
    "permissions": [{
      "actions": [
        "Microsoft.Authorization/*/read",
        "Microsoft.Authorization/locks/read",
        "Microsoft.Authorization/locks/write",
        "Microsoft.Authorization/locks/delete",
        "Microsoft.Resources/subscriptions/read",
        "Microsoft.Resources/subscriptions/locations/read",
        "Microsoft.Resources/subscriptions/providers/read",
        "Microsoft.Resources/subscriptions/resourceGroups/read",
        "Microsoft.Resources/subscriptions/resourceGroups/write",
        "Microsoft.Resources/subscriptions/resourceGroups/delete",
        "Microsoft.OperationalInsights/workspaces/read",
        "Microsoft.Insights/diagnosticSettings/read",
        "Microsoft.Insights/diagnosticSettings/write",
        "Microsoft.Insights/diagnosticSettings/delete",

        "Microsoft.ContainerRegistry/checkNameAvailability/read",
        "Microsoft.ContainerRegistry/operations/read",
        "Microsoft.ContainerRegistry/locations/operationResults/read",
        "Microsoft.ContainerRegistry/registries/read",
        "Microsoft.ContainerRegistry/registries/write",
        "Microsoft.ContainerRegistry/registries/delete",
        "Microsoft.ContainerRegistry/registries/operationStatuses/read",
        "Microsoft.ContainerRegistry/registries/privateEndpointConnectionsApproval/action",

        "Microsoft.Storage/checknameavailability/read",
        "Microsoft.Storage/operations/read",
        "Microsoft.Storage/skus/read",
        "Microsoft.Storage/locations/usages/read",
        "Microsoft.Storage/storageAccounts/read",
        "Microsoft.Storage/storageAccounts/write",
        "Microsoft.Storage/storageAccounts/delete",
        "Microsoft.Storage/storageAccounts/blobServices/read",
        "Microsoft.Storage/storageAccounts/privateEndpointConnectionsApproval/action",

        "Microsoft.KeyVault/checkNameAvailability/read",
        "Microsoft.KeyVault/deletedVaults/read",
        "Microsoft.KeyVault/operations/read",
        "Microsoft.KeyVault/locations/*/read",
        "Microsoft.KeyVault/vaults/read",
        "Microsoft.KeyVault/vaults/write",
        "Microsoft.KeyVault/vaults/delete",
        "Microsoft.KeyVault/vaults/privateLinkResources/read",
        "Microsoft.KeyVault/vaults/PrivateEndpointConnectionsApproval/action",

        "Microsoft.ServiceBus/operations/read",
        "Microsoft.ServiceBus/checkNameAvailability/action",
        "Microsoft.ServiceBus/namespaces/read",
        "Microsoft.ServiceBus/namespaces/write",
        "Microsoft.ServiceBus/namespaces/delete",
        "Microsoft.ServiceBus/namespaces/privateLinkResources/read",
        "Microsoft.ServiceBus/namespaces/privateEndpointConnectionsApproval/action",

        "Microsoft.Cache/checknameavailability/action",
        "Microsoft.Cache/locations/checknameavailability/action",
        "Microsoft.Cache/locations/asyncOperations/read",
        "Microsoft.Cache/redisEnterprise/read",
        "Microsoft.Cache/redisEnterprise/write",
        "Microsoft.Cache/redisEnterprise/delete",
        "Microsoft.Cache/redisEnterprise/operationResults/read",
        "Microsoft.Cache/redisEnterprise/privateLinkResources/read",
        "Microsoft.Cache/redisEnterprise/PrivateEndpointConnectionsApproval/action",
        "Microsoft.Cache/redisEnterprise/databases/read",
        "Microsoft.Cache/redisEnterprise/databases/write",
        "Microsoft.Cache/redisEnterprise/databases/delete",
        "Microsoft.Cache/redisEnterprise/databases/operationResults/read",

        "Microsoft.DBforPostgreSQL/*/read",
        "Microsoft.DBforPostgreSQL/flexibleServers/write",
        "Microsoft.DBforPostgreSQL/flexibleServers/delete",
        "Microsoft.DBforPostgreSQL/flexibleServers/administrators/write",
        "Microsoft.DBforPostgreSQL/flexibleServers/administrators/delete",

        "Microsoft.Network/virtualNetworks/read",
        "Microsoft.Network/virtualNetworks/subnets/read",
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/networkInterfaces/read",
        "Microsoft.Network/privateDnsZones/read",
        "Microsoft.Network/privateDnsZones/join/action",
        "Microsoft.Network/privateEndpoints/read",
        "Microsoft.Network/privateEndpoints/write",
        "Microsoft.Network/privateEndpoints/delete",
        "Microsoft.Network/privateEndpoints/privateDnsZoneGroups/read",
        "Microsoft.Network/privateEndpoints/privateDnsZoneGroups/write",
        "Microsoft.Network/privateEndpoints/privateDnsZoneGroups/delete",
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
p=role['properties']['permissions'][0]
a=set(p['actions'])
required={
 'Microsoft.ContainerRegistry/registries/write',
 'Microsoft.Storage/storageAccounts/write',
 'Microsoft.KeyVault/vaults/write',
 'Microsoft.ServiceBus/namespaces/write',
 'Microsoft.Cache/redisEnterprise/write',
 'Microsoft.Cache/redisEnterprise/databases/write',
 'Microsoft.DBforPostgreSQL/flexibleServers/write',
 'Microsoft.DBforPostgreSQL/flexibleServers/administrators/write',
 'Microsoft.Network/privateEndpoints/write',
 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups/write',
 'Microsoft.Network/virtualNetworks/subnets/join/action',
 'Microsoft.Network/privateDnsZones/join/action',
 'Microsoft.Insights/diagnosticSettings/write',
 'Microsoft.Authorization/locks/write',
}
assert required <= a, required-a
forbidden={
 'Microsoft.Authorization/roleAssignments/write',
 'Microsoft.Authorization/roleAssignments/delete',
 'Microsoft.Network/*',
 'Microsoft.Storage/storageAccounts/listkeys/action',
 'Microsoft.ContainerRegistry/registries/listCredentials/action',
 'Microsoft.ServiceBus/namespaces/authorizationRules/listkeys/action',
 'Microsoft.Cache/redisEnterprise/databases/listKeys/action',
 'Microsoft.KeyVault/vaults/secrets/getSecret/action',
}
assert not (forbidden & a), forbidden & a
assert p['dataActions'] == [], 'workload Apply must not receive service data-plane access'
for action in a:
    low=action.lower()
    assert 'roleassignments/write' not in low
    assert 'listkeys/action' not in low
    assert 'listcredentials/action' not in low
print('Workload services custom-role contract valid.')
PY

log "Identity: ${IDENTITY_NAME} -> ${GITHUB_ENVIRONMENT}"
log "Role: ${ROLE_NAME} (${ROLE_ID})"
if [[ "$APPLY" -eq 0 ]]; then
  cat <<EOF
PLAN ONLY - no Azure mutation.
Planned mutations:
  1. Create/normalize dedicated ${ENV_UPPER} Workload Apply UAMI and OIDC FIC.
  2. Create/update narrow Workload Services custom role.
  3. Assign that role at subscription scope and Blob Data Contributor only on tfstate container.
Supported Apply services:
  acr, storage, key-vault, service-bus, managed-redis, postgresql-flexible
Explicitly not granted:
  RBAC writes, service credentials/listKeys, Key Vault secret data access, broad Microsoft.Network/*.
EOF
  exit 0
fi

log "Registering required resource providers"
for provider in Microsoft.ManagedIdentity Microsoft.ContainerRegistry Microsoft.Storage Microsoft.KeyVault Microsoft.ServiceBus Microsoft.Cache Microsoft.DBforPostgreSQL Microsoft.Network Microsoft.Insights Microsoft.OperationalInsights; do
  az provider register --namespace "$provider" --wait --output none
 done

IDENTITY_BODY="$(printf '{"location":"%s","tags":{"managed_by":"iac-control-plane-bootstrap","environment":"%s","capability":"workload-services"}}' "$LOCATION" "$ENVIRONMENT")"
put_json "${STATE_RG_SCOPE}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${IDENTITY_NAME}" "2023-01-31" "$IDENTITY_BODY"
CLIENT_ID="$(identity_field clientId)"
PRINCIPAL_ID="$(identity_field principalId)"
[[ -n "$CLIENT_ID" && -n "$PRINCIPAL_ID" ]] || fail "failed to resolve Workload Apply UAMI IDs"

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
  "status": "READY_FOR_IAC_WORKLOAD_GITHUB_BINDING",
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
  "supportedServices": ["acr", "storage", "key-vault", "service-bus", "managed-redis", "postgresql-flexible"],
  "roleAssignmentWrite": false,
  "serviceCredentialRead": false,
  "keyVaultSecretDataAccess": false,
  "genericNetworkContributor": false
}
EOF
python3 -m json.tool "$RESULT_FILE" >/dev/null
log "Workload services capability activation complete: $RESULT_FILE"
