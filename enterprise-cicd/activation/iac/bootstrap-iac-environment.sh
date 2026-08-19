#!/usr/bin/env bash
set -euo pipefail

# One-time privileged bootstrap for TEST/PROD IaC runtime identities.
# DEV remains owned by bootstrap-dev-iac-control-plane.sh because DEV also
# bootstraps the shared Entra-only Terraform state backend.
#
# Default: PLAN ONLY.
# Usage:
#   ./bootstrap-iac-environment.sh --environment test
#   ./bootstrap-iac-environment.sh --environment test --apply
#   ./bootstrap-iac-environment.sh --environment prod
#   ./bootstrap-iac-environment.sh --environment prod --apply

ENVIRONMENT=""
APPLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --environment)
      ENVIRONMENT="${2:-}"
      shift 2
      ;;
    --apply)
      APPLY=1
      shift
      ;;
    *)
      echo "usage: $0 --environment test|prod [--apply]" >&2
      exit 2
      ;;
  esac
done

[[ "$ENVIRONMENT" == "test" || "$ENVIRONMENT" == "prod" ]] || {
  echo "--environment must be test or prod" >&2
  exit 2
}

SUBSCRIPTION_ID="c12c3a36-99d8-4741-bcef-cd7df5d5cd4a"
TENANT_ID="a1c6a587-dc3b-40a5-9438-445d896bb5f2"
LOCATION="eastus"
REPOSITORY="iwacollection/k3s-gitops"
ISSUER="https://token.actions.githubusercontent.com"
AUDIENCE="api://AzureADTokenExchange"

STATE_RG="rg-platform-cicd"
STATE_STORAGE="sttfstatec12c3a3699d8"
STATE_CONTAINER="tfstate"

PLAN_IDENTITY_NAME="k3s-gitops-iac-plan-${ENVIRONMENT}-uami"
APPLY_IDENTITY_NAME="k3s-gitops-iac-apply-${ENVIRONMENT}-uami"
PLAN_GITHUB_ENVIRONMENT="iac-${ENVIRONMENT}-plan"
APPLY_GITHUB_ENVIRONMENT="iac-${ENVIRONMENT}-apply"
PLAN_FIC_NAME="github-iac-${ENVIRONMENT}-plan"
APPLY_FIC_NAME="github-iac-${ENVIRONMENT}-apply"

ENV_UPPER="$(printf '%s' "$ENVIRONMENT" | tr '[:lower:]' '[:upper:]')"
CUSTOM_APPLY_ROLE_NAME="Enterprise IaC Managed Identity ${ENV_UPPER} Apply"

READER_ROLE_ID="acdd72a7-3385-48ef-bd42-f606fba81ae7"
STORAGE_BLOB_DATA_CONTRIBUTOR_ROLE_ID="ba92f5b4-2d11-453d-a403-e96b0029c9fe"

# Stable deterministic GUIDs keep repeated bootstrap idempotent without
# hard-coding a growing collection of environment-specific UUIDs.
read -r CUSTOM_APPLY_ROLE_ID PLAN_READER_ASSIGNMENT_ID PLAN_STATE_ASSIGNMENT_ID APPLY_CUSTOM_ASSIGNMENT_ID APPLY_STATE_ASSIGNMENT_ID < <(
python3 - "$ENVIRONMENT" <<'PY'
import sys, uuid
env = sys.argv[1]
ns = uuid.UUID('f83a91a5-0416-4d8a-bb9b-a448a76e7c78')
for name in (
    f'role:managed-identity:{env}:apply',
    f'assignment:{env}:plan:reader',
    f'assignment:{env}:plan:state',
    f'assignment:{env}:apply:managed-identity',
    f'assignment:{env}:apply:state',
):
    print(uuid.uuid5(ns, name), end=' ')
print()
PY
)

RESULT_FILE="${ENVIRONMENT}-iac-control-plane-bootstrap-result.json"
SUB_SCOPE="/subscriptions/${SUBSCRIPTION_ID}"
STATE_RG_SCOPE="${SUB_SCOPE}/resourceGroups/${STATE_RG}"
STATE_STORAGE_SCOPE="${STATE_RG_SCOPE}/providers/Microsoft.Storage/storageAccounts/${STATE_STORAGE}"
STATE_CONTAINER_SCOPE="${STATE_STORAGE_SCOPE}/blobServices/default/containers/${STATE_CONTAINER}"
CUSTOM_APPLY_ROLE_DEFINITION_ID="${SUB_SCOPE}/providers/Microsoft.Authorization/roleDefinitions/${CUSTOM_APPLY_ROLE_ID}"

log() { printf '[iac-%s-bootstrap] %s\n' "$ENVIRONMENT" "$*"; }
fail() { printf '[iac-%s-bootstrap][ERROR] %s\n' "$ENVIRONMENT" "$*" >&2; exit 1; }
arm_url() { printf 'https://management.azure.com%s' "$1"; }

put_json() {
  local path="$1" api_version="$2" body="$3"
  az rest --method put \
    --url "$(arm_url "${path}?api-version=${api_version}")" \
    --headers 'Content-Type=application/json' \
    --body "$body" --output none
}

ensure_role_assignment() {
  local scope="$1" assignment_id="$2" principal_id="$3" role_definition_id="$4"
  local body
  body="$(cat <<EOF
{"properties":{"principalId":"${principal_id}","principalType":"ServicePrincipal","roleDefinitionId":"${role_definition_id}"}}
EOF
)"
  put_json "${scope}/providers/Microsoft.Authorization/roleAssignments/${assignment_id}" "2022-04-01" "$body"
}

ensure_fic() {
  local identity_name="$1" fic_name="$2" subject="$3"
  local body
  body="$(cat <<EOF
{"properties":{"issuer":"${ISSUER}","subject":"${subject}","audiences":["${AUDIENCE}"]}}
EOF
)"
  put_json "${STATE_RG_SCOPE}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${identity_name}/federatedIdentityCredentials/${fic_name}" "2024-11-30" "$body"
}

identity_field() {
  local identity_name="$1" field="$2"
  az rest --method get \
    --url "$(arm_url "${STATE_RG_SCOPE}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${identity_name}?api-version=2023-01-31")" \
    --query "properties.${field}" -o tsv
}

command -v az >/dev/null 2>&1 || fail "Azure CLI is required"
command -v python3 >/dev/null 2>&1 || fail "python3 is required"
az account show >/dev/null 2>&1 || fail "Azure CLI is not authenticated"
[[ "$(az account show --query tenantId -o tsv)" == "$TENANT_ID" ]] || fail "unexpected Azure tenant"
az account set --subscription "$SUBSCRIPTION_ID"
[[ "$(az account show --query id -o tsv)" == "$SUBSCRIPTION_ID" ]] || fail "unexpected Azure subscription"

# TEST/PROD must reuse the already governed shared state control plane.
az rest --method get --url "$(arm_url "${STATE_RG_SCOPE}?api-version=2022-09-01")" --output none >/dev/null || fail "shared state resource group is missing"
az rest --method get --url "$(arm_url "${STATE_STORAGE_SCOPE}?api-version=2023-05-01")" --output none >/dev/null || fail "shared state storage account is missing"
SHARED_KEY="$(az rest --method get --url "$(arm_url "${STATE_STORAGE_SCOPE}?api-version=2023-05-01")" --query properties.allowSharedKeyAccess -o tsv)"
[[ "$SHARED_KEY" == "false" || "$SHARED_KEY" == "False" ]] || fail "tfstate Shared Key access must remain disabled"

log "Plan identity: $PLAN_IDENTITY_NAME -> $PLAN_GITHUB_ENVIRONMENT"
log "Apply identity: $APPLY_IDENTITY_NAME -> $APPLY_GITHUB_ENVIRONMENT"
log "Shared state: $STATE_RG / $STATE_STORAGE / $STATE_CONTAINER"

if [[ "$APPLY" -eq 0 ]]; then
  log "PLAN ONLY - no Azure mutation will be performed"
  cat <<EOF

Planned Azure mutations:
  1. Create/normalize TEST/PROD-specific Plan UAMI and Apply UAMI in ${STATE_RG}
  2. Create GitHub OIDC FICs for ${PLAN_GITHUB_ENVIRONMENT} and ${APPLY_GITHUB_ENVIRONMENT}
  3. Plan UAMI: subscription Reader + tfstate-container Storage Blob Data Contributor
  4. Apply UAMI: narrow resource-group/UAMI custom role + tfstate-container Storage Blob Data Contributor

Explicitly NOT granted:
  - Owner
  - generic Contributor
  - User Access Administrator
  - Microsoft.Authorization/roleAssignments/write
  - Kubernetes write permissions

PROD execution remains additionally gated by GitHub Environment ${APPLY_GITHUB_ENVIRONMENT}.
EOF
  exit 0
fi

log "Registering Managed Identity provider"
az provider register --namespace Microsoft.ManagedIdentity --wait --output none

IDENTITY_BODY="$(cat <<EOF
{"location":"${LOCATION}","tags":{"managed_by":"iac-control-plane-bootstrap","environment":"${ENVIRONMENT}","purpose":"terraform-github-oidc"}}
EOF
)"
put_json "${STATE_RG_SCOPE}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${PLAN_IDENTITY_NAME}" "2023-01-31" "$IDENTITY_BODY"
put_json "${STATE_RG_SCOPE}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${APPLY_IDENTITY_NAME}" "2023-01-31" "$IDENTITY_BODY"

PLAN_CLIENT_ID="$(identity_field "$PLAN_IDENTITY_NAME" clientId)"
PLAN_PRINCIPAL_ID="$(identity_field "$PLAN_IDENTITY_NAME" principalId)"
APPLY_CLIENT_ID="$(identity_field "$APPLY_IDENTITY_NAME" clientId)"
APPLY_PRINCIPAL_ID="$(identity_field "$APPLY_IDENTITY_NAME" principalId)"
[[ -n "$PLAN_CLIENT_ID" && -n "$PLAN_PRINCIPAL_ID" && -n "$APPLY_CLIENT_ID" && -n "$APPLY_PRINCIPAL_ID" ]] || fail "failed to resolve UAMI IDs"

ensure_fic "$PLAN_IDENTITY_NAME" "$PLAN_FIC_NAME" "repo:${REPOSITORY}:environment:${PLAN_GITHUB_ENVIRONMENT}"
ensure_fic "$APPLY_IDENTITY_NAME" "$APPLY_FIC_NAME" "repo:${REPOSITORY}:environment:${APPLY_GITHUB_ENVIRONMENT}"

CUSTOM_ROLE_BODY="$(cat <<EOF
{
  "properties": {
    "roleName": "${CUSTOM_APPLY_ROLE_NAME}",
    "description": "${ENV_UPPER} IaC capability limited to resource-group lifecycle and user-assigned managed identities. No generic Contributor or RBAC assignment write.",
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
        "Microsoft.ManagedIdentity/*/read",
        "Microsoft.ManagedIdentity/userAssignedIdentities/write",
        "Microsoft.ManagedIdentity/userAssignedIdentities/delete"
      ],
      "notActions": [], "dataActions": [], "notDataActions": []
    }],
    "assignableScopes": ["${SUB_SCOPE}"]
  }
}
EOF
)"
put_json "${SUB_SCOPE}/providers/Microsoft.Authorization/roleDefinitions/${CUSTOM_APPLY_ROLE_ID}" "2022-04-01" "$CUSTOM_ROLE_BODY"

ensure_role_assignment "$SUB_SCOPE" "$PLAN_READER_ASSIGNMENT_ID" "$PLAN_PRINCIPAL_ID" "${SUB_SCOPE}/providers/Microsoft.Authorization/roleDefinitions/${READER_ROLE_ID}"
ensure_role_assignment "$STATE_CONTAINER_SCOPE" "$PLAN_STATE_ASSIGNMENT_ID" "$PLAN_PRINCIPAL_ID" "${SUB_SCOPE}/providers/Microsoft.Authorization/roleDefinitions/${STORAGE_BLOB_DATA_CONTRIBUTOR_ROLE_ID}"
ensure_role_assignment "$SUB_SCOPE" "$APPLY_CUSTOM_ASSIGNMENT_ID" "$APPLY_PRINCIPAL_ID" "$CUSTOM_APPLY_ROLE_DEFINITION_ID"
ensure_role_assignment "$STATE_CONTAINER_SCOPE" "$APPLY_STATE_ASSIGNMENT_ID" "$APPLY_PRINCIPAL_ID" "${SUB_SCOPE}/providers/Microsoft.Authorization/roleDefinitions/${STORAGE_BLOB_DATA_CONTRIBUTOR_ROLE_ID}"

cat > "$RESULT_FILE" <<EOF
{
  "status": "READY_FOR_IAC_GITHUB_BINDING",
  "environment": "${ENVIRONMENT}",
  "subscriptionId": "${SUBSCRIPTION_ID}",
  "tenantId": "${TENANT_ID}",
  "state": {
    "resourceGroup": "${STATE_RG}",
    "storageAccount": "${STATE_STORAGE}",
    "container": "${STATE_CONTAINER}",
    "authentication": "MicrosoftEntraID",
    "sharedKeyAccess": false
  },
  "plan": {
    "githubEnvironment": "${PLAN_GITHUB_ENVIRONMENT}",
    "identityName": "${PLAN_IDENTITY_NAME}",
    "clientId": "${PLAN_CLIENT_ID}",
    "principalId": "${PLAN_PRINCIPAL_ID}",
    "resourceId": "${STATE_RG_SCOPE}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${PLAN_IDENTITY_NAME}",
    "federatedCredential": "${PLAN_FIC_NAME}",
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
    "stateDataRole": "Storage Blob Data Contributor",
    "stateScope": "container",
    "genericContributor": false,
    "roleAssignmentWrite": false
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
log "Activation evidence written to $RESULT_FILE"
