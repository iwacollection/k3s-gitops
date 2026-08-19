#!/usr/bin/env bash
set -euo pipefail

# One-time privileged bootstrap for the DEV IaC control plane.
# Default: PLAN ONLY. Pass --apply to perform Azure mutations.
#
# This script intentionally does NOT elevate the existing application/CI OIDC identity.
# It creates separate GitHub OIDC identities for IaC Plan and IaC Apply.
#
# The azurerm backend uses Azure Blob native state locking. Therefore the Plan
# identity needs container-scoped Storage Blob Data Contributor for state/lease
# operations, while remaining Azure-resource read-only at the management plane.

APPLY=0
if [[ "${1:-}" == "--apply" ]]; then
  APPLY=1
elif [[ -n "${1:-}" ]]; then
  echo "usage: $0 [--apply]" >&2
  exit 2
fi

SUBSCRIPTION_ID="c12c3a36-99d8-4741-bcef-cd7df5d5cd4a"
TENANT_ID="a1c6a587-dc3b-40a5-9438-445d896bb5f2"
LOCATION="eastus"
REPOSITORY="iwacollection/k3s-gitops"
ISSUER="https://token.actions.githubusercontent.com"
AUDIENCE="api://AzureADTokenExchange"

STATE_RG="rg-platform-cicd"
STATE_STORAGE="sttfstatec12c3a3699d8"
STATE_CONTAINER="tfstate"

PLAN_IDENTITY_NAME="k3s-gitops-iac-plan-dev-uami"
APPLY_IDENTITY_NAME="k3s-gitops-iac-apply-dev-uami"
PLAN_GITHUB_ENVIRONMENT="iac-dev-plan"
APPLY_GITHUB_ENVIRONMENT="iac-dev-apply"
PLAN_FIC_NAME="github-iac-dev-plan"
APPLY_FIC_NAME="github-iac-dev-apply"

CUSTOM_APPLY_ROLE_NAME="Enterprise IaC Managed Identity DEV Apply"
CUSTOM_APPLY_ROLE_ID="5ac62889-bba2-5e30-a0cf-a63ec3ce6fc3"

READER_ROLE_ID="acdd72a7-3385-48ef-bd42-f606fba81ae7"
STORAGE_BLOB_DATA_CONTRIBUTOR_ROLE_ID="ba92f5b4-2d11-453d-a403-e96b0029c9fe"

PLAN_READER_ASSIGNMENT_ID="41d1d533-cced-5c75-bd36-e342b9a66836"
PLAN_STATE_ASSIGNMENT_ID="645715ac-50ed-48f4-a4d6-2e03ae6ba8f9"
APPLY_CUSTOM_ASSIGNMENT_ID="79e8566c-26fb-519e-8d33-36ff801af1ca"
APPLY_STATE_ASSIGNMENT_ID="936f24cd-2d9d-5eab-8485-a70a75b57905"

RESULT_FILE="dev-iac-control-plane-bootstrap-result.json"
SUB_SCOPE="/subscriptions/${SUBSCRIPTION_ID}"
STATE_RG_SCOPE="${SUB_SCOPE}/resourceGroups/${STATE_RG}"
STATE_STORAGE_SCOPE="${STATE_RG_SCOPE}/providers/Microsoft.Storage/storageAccounts/${STATE_STORAGE}"
STATE_CONTAINER_SCOPE="${STATE_STORAGE_SCOPE}/blobServices/default/containers/${STATE_CONTAINER}"
CUSTOM_APPLY_ROLE_DEFINITION_ID="${SUB_SCOPE}/providers/Microsoft.Authorization/roleDefinitions/${CUSTOM_APPLY_ROLE_ID}"

log() {
  printf '[iac-bootstrap] %s\n' "$*"
}

fail() {
  printf '[iac-bootstrap][ERROR] %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 is required"
}

arm_url() {
  printf 'https://management.azure.com%s' "$1"
}

put_json() {
  local path="$1"
  local api_version="$2"
  local body="$3"
  az rest \
    --method put \
    --url "$(arm_url "${path}?api-version=${api_version}")" \
    --headers 'Content-Type=application/json' \
    --body "$body" \
    --output none
}

get_json_or_empty() {
  local path="$1"
  local api_version="$2"
  az rest \
    --method get \
    --url "$(arm_url "${path}?api-version=${api_version}")" \
    --output json 2>/dev/null || printf '{}\n'
}

ensure_role_assignment() {
  local scope="$1"
  local assignment_id="$2"
  local principal_id="$3"
  local role_definition_id="$4"
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
  put_json "${scope}/providers/Microsoft.Authorization/roleAssignments/${assignment_id}" "2022-04-01" "$body"
}

ensure_fic() {
  local identity_name="$1"
  local fic_name="$2"
  local subject="$3"
  local body
  body="$(cat <<EOF
{
  "properties": {
    "issuer": "${ISSUER}",
    "subject": "${subject}",
    "audiences": ["${AUDIENCE}"]
  }
}
EOF
)"
  put_json "${STATE_RG_SCOPE}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${identity_name}/federatedIdentityCredentials/${fic_name}" "2024-11-30" "$body"
}

identity_field() {
  local identity_name="$1"
  local field="$2"
  az rest \
    --method get \
    --url "$(arm_url "${STATE_RG_SCOPE}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${identity_name}?api-version=2023-01-31")" \
    --query "properties.${field}" -o tsv
}

require_cmd az
require_cmd python3

log "Checking Azure CLI login"
az account show >/dev/null 2>&1 || fail "Azure CLI is not authenticated. Run: az login"

CURRENT_TENANT="$(az account show --query tenantId -o tsv)"
[[ "$CURRENT_TENANT" == "$TENANT_ID" ]] || fail "current tenant=$CURRENT_TENANT expected=$TENANT_ID"

az account set --subscription "$SUBSCRIPTION_ID"
CURRENT_SUBSCRIPTION="$(az account show --query id -o tsv)"
[[ "$CURRENT_SUBSCRIPTION" == "$SUBSCRIPTION_ID" ]] || fail "current subscription=$CURRENT_SUBSCRIPTION expected=$SUBSCRIPTION_ID"

log "Target subscription: $SUBSCRIPTION_ID"
log "State: $STATE_RG / $STATE_STORAGE / $STATE_CONTAINER"
log "Plan identity: $PLAN_IDENTITY_NAME -> GitHub environment $PLAN_GITHUB_ENVIRONMENT"
log "Apply identity: $APPLY_IDENTITY_NAME -> GitHub environment $APPLY_GITHUB_ENVIRONMENT"

if [[ "$APPLY" -eq 0 ]]; then
  log "PLAN ONLY - no Azure mutation will be performed"
  printf '\nPlanned Azure mutations:\n'
  printf '  1. Create/normalize resource group %s\n' "$STATE_RG"
  printf '  2. Create/normalize Entra-only tfstate Storage Account %s (Standard_LRS)\n' "$STATE_STORAGE"
  printf '  3. Create private blob container %s\n' "$STATE_CONTAINER"
  printf '  4. Create UAMI %s + FIC subject environment:%s\n' "$PLAN_IDENTITY_NAME" "$PLAN_GITHUB_ENVIRONMENT"
  printf '  5. Create UAMI %s + FIC subject environment:%s\n' "$APPLY_IDENTITY_NAME" "$APPLY_GITHUB_ENVIRONMENT"
  printf '  6. Plan UAMI: subscription Reader + tfstate container Storage Blob Data Contributor (backend state/lease only)\n'
  printf '  7. Apply UAMI: narrow custom managed-identity apply role + tfstate container Storage Blob Data Contributor\n'
  printf '\nNo Contributor/Owner Azure resource role is assigned to either GitHub IaC identity.\n'
  printf 'Run with mutations enabled:\n  %s --apply\n' "$0"
  exit 0
fi

log "APPLY mode enabled"
log "Verifying bootstrap operator can manage role definitions and assignments"
az rest \
  --method get \
  --url "$(arm_url "${SUB_SCOPE}/providers/Microsoft.Authorization/roleDefinitions?api-version=2022-04-01&%24filter=type%20eq%20%27CustomRole%27")" \
  --output none >/dev/null

log "Registering required resource providers"
az provider register --namespace Microsoft.ManagedIdentity --wait --output none
az provider register --namespace Microsoft.Storage --wait --output none

log "Creating/normalizing state resource group"
RG_BODY="$(cat <<EOF
{
  "location": "${LOCATION}",
  "tags": {
    "managed_by": "iac-control-plane-bootstrap",
    "environment": "dev",
    "purpose": "terraform-state-and-identities"
  }
}
EOF
)"
put_json "$STATE_RG_SCOPE" "2022-09-01" "$RG_BODY"

log "Creating/normalizing Terraform state storage account"
STORAGE_BODY="$(cat <<EOF
{
  "sku": {"name": "Standard_LRS"},
  "kind": "StorageV2",
  "location": "${LOCATION}",
  "tags": {
    "managed_by": "iac-control-plane-bootstrap",
    "environment": "dev",
    "purpose": "terraform-state"
  },
  "properties": {
    "supportsHttpsTrafficOnly": true,
    "minimumTlsVersion": "TLS1_2",
    "allowBlobPublicAccess": false,
    "allowSharedKeyAccess": false,
    "publicNetworkAccess": "Enabled"
  }
}
EOF
)"
put_json "$STATE_STORAGE_SCOPE" "2023-05-01" "$STORAGE_BODY"

log "Waiting for storage provisioning"
for _ in $(seq 1 60); do
  PROVISIONING_STATE="$(az rest --method get --url "$(arm_url "${STATE_STORAGE_SCOPE}?api-version=2023-05-01")" --query properties.provisioningState -o tsv 2>/dev/null || true)"
  [[ "$PROVISIONING_STATE" == "Succeeded" ]] && break
  sleep 2
done
[[ "${PROVISIONING_STATE:-}" == "Succeeded" ]] || fail "state storage did not reach Succeeded"

log "Creating/normalizing private tfstate container through ARM control plane"
CONTAINER_BODY='{"properties":{"publicAccess":"None"}}'
put_json "${STATE_STORAGE_SCOPE}/blobServices/default/containers/${STATE_CONTAINER}" "2023-05-01" "$CONTAINER_BODY"

log "Creating/normalizing dedicated Plan and Apply managed identities"
IDENTITY_BODY="$(cat <<EOF
{
  "location": "${LOCATION}",
  "tags": {
    "managed_by": "iac-control-plane-bootstrap",
    "environment": "dev",
    "purpose": "terraform-github-oidc"
  }
}
EOF
)"
put_json "${STATE_RG_SCOPE}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${PLAN_IDENTITY_NAME}" "2023-01-31" "$IDENTITY_BODY"
put_json "${STATE_RG_SCOPE}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${APPLY_IDENTITY_NAME}" "2023-01-31" "$IDENTITY_BODY"

PLAN_CLIENT_ID="$(identity_field "$PLAN_IDENTITY_NAME" clientId)"
PLAN_PRINCIPAL_ID="$(identity_field "$PLAN_IDENTITY_NAME" principalId)"
APPLY_CLIENT_ID="$(identity_field "$APPLY_IDENTITY_NAME" clientId)"
APPLY_PRINCIPAL_ID="$(identity_field "$APPLY_IDENTITY_NAME" principalId)"
[[ -n "$PLAN_CLIENT_ID" && -n "$PLAN_PRINCIPAL_ID" && -n "$APPLY_CLIENT_ID" && -n "$APPLY_PRINCIPAL_ID" ]] || fail "failed to resolve UAMI IDs"

log "Creating/normalizing GitHub OIDC federated credentials"
ensure_fic "$PLAN_IDENTITY_NAME" "$PLAN_FIC_NAME" "repo:${REPOSITORY}:environment:${PLAN_GITHUB_ENVIRONMENT}"
ensure_fic "$APPLY_IDENTITY_NAME" "$APPLY_FIC_NAME" "repo:${REPOSITORY}:environment:${APPLY_GITHUB_ENVIRONMENT}"

log "Creating/normalizing narrow custom Apply role"
CUSTOM_ROLE_BODY="$(cat <<EOF
{
  "properties": {
    "roleName": "${CUSTOM_APPLY_ROLE_NAME}",
    "description": "DEV catalog apply role limited to resource-group lifecycle and user-assigned managed identities; no RBAC assignment write and no generic Contributor access.",
    "type": "CustomRole",
    "permissions": [
      {
        "actions": [
          "Microsoft.Authorization/*/read",
          "Microsoft.Resources/subscriptions/read",
          "Microsoft.Resources/subscriptions/locations/read",
          "Microsoft.Resources/subscriptions/providers/read",
          "Microsoft.Resources/subscriptions/resourceGroups/read",
          "Microsoft.Resources/subscriptions/resourceGroups/write",
          "Microsoft.Resources/subscriptions/resourceGroups/delete",
          "Microsoft.ManagedIdentity/*/read",
          "Microsoft.ManagedIdentity/userAssignedIdentities/write",
          "Microsoft.ManagedIdentity/userAssignedIdentities/delete"
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
put_json "${SUB_SCOPE}/providers/Microsoft.Authorization/roleDefinitions/${CUSTOM_APPLY_ROLE_ID}" "2022-04-01" "$CUSTOM_ROLE_BODY"

log "Assigning Plan identity: subscription Reader + state container backend contributor"
ensure_role_assignment "$SUB_SCOPE" "$PLAN_READER_ASSIGNMENT_ID" "$PLAN_PRINCIPAL_ID" "${SUB_SCOPE}/providers/Microsoft.Authorization/roleDefinitions/${READER_ROLE_ID}"
ensure_role_assignment "$STATE_CONTAINER_SCOPE" "$PLAN_STATE_ASSIGNMENT_ID" "$PLAN_PRINCIPAL_ID" "${SUB_SCOPE}/providers/Microsoft.Authorization/roleDefinitions/${STORAGE_BLOB_DATA_CONTRIBUTOR_ROLE_ID}"

log "Assigning Apply identity: narrow resource role + state container contributor"
ensure_role_assignment "$SUB_SCOPE" "$APPLY_CUSTOM_ASSIGNMENT_ID" "$APPLY_PRINCIPAL_ID" "$CUSTOM_APPLY_ROLE_DEFINITION_ID"
ensure_role_assignment "$STATE_CONTAINER_SCOPE" "$APPLY_STATE_ASSIGNMENT_ID" "$APPLY_PRINCIPAL_ID" "${SUB_SCOPE}/providers/Microsoft.Authorization/roleDefinitions/${STORAGE_BLOB_DATA_CONTRIBUTOR_ROLE_ID}"

log "Writing non-secret activation evidence: $RESULT_FILE"
cat > "$RESULT_FILE" <<EOF
{
  "status": "READY_FOR_IAC_GITHUB_BINDING",
  "subscriptionId": "${SUBSCRIPTION_ID}",
  "tenantId": "${TENANT_ID}",
  "location": "${LOCATION}",
  "state": {
    "resourceGroup": "${STATE_RG}",
    "storageAccount": "${STATE_STORAGE}",
    "container": "${STATE_CONTAINER}",
    "sharedKeyAccess": false,
    "blobPublicAccess": false,
    "sku": "Standard_LRS"
  },
  "plan": {
    "githubEnvironment": "${PLAN_GITHUB_ENVIRONMENT}",
    "identityName": "${PLAN_IDENTITY_NAME}",
    "clientId": "${PLAN_CLIENT_ID}",
    "principalId": "${PLAN_PRINCIPAL_ID}",
    "resourceId": "${STATE_RG_SCOPE}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${PLAN_IDENTITY_NAME}",
    "federatedCredential": "${PLAN_FIC_NAME}",
    "subject": "repo:${REPOSITORY}:environment:${PLAN_GITHUB_ENVIRONMENT}",
    "stateDataRole": "Storage Blob Data Contributor",
    "stateScope": "container",
    "resourceWriteAccess": false
  },
  "apply": {
    "githubEnvironment": "${APPLY_GITHUB_ENVIRONMENT}",
    "identityName": "${APPLY_IDENTITY_NAME}",
    "clientId": "${APPLY_CLIENT_ID}",
    "principalId": "${APPLY_PRINCIPAL_ID}",
    "resourceId": "${STATE_RG_SCOPE}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${APPLY_IDENTITY_NAME}",
    "federatedCredential": "${APPLY_FIC_NAME}",
    "subject": "repo:${REPOSITORY}:environment:${APPLY_GITHUB_ENVIRONMENT}",
    "stateDataRole": "Storage Blob Data Contributor",
    "stateScope": "container"
  },
  "applyRole": {
    "name": "${CUSTOM_APPLY_ROLE_NAME}",
    "id": "${CUSTOM_APPLY_ROLE_ID}",
    "genericContributor": false,
    "roleAssignmentWrite": false
  }
}
EOF

python3 -m json.tool "$RESULT_FILE" >/dev/null
cat "$RESULT_FILE"

log "Bootstrap complete"
log "Next: bind the returned Plan/Apply IDs in iac-runtime-bindings.json, then run the GitHub remote-state Plan gate."
