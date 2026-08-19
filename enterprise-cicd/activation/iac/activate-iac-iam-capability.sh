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

IDENTITY_NAME="k3s-gitops-iac-iam-apply-${ENVIRONMENT}-uami"
GITHUB_ENVIRONMENT="iac-${ENVIRONMENT}-iam-apply"
FIC_NAME="github-iac-${ENVIRONMENT}-iam-apply"

RBAC_ADMIN_ROLE_ID="f58310d9-a9f6-439a-9e8d-f62e7b41a168"
STORAGE_BLOB_DATA_CONTRIBUTOR_ROLE_ID="ba92f5b4-2d11-453d-a403-e96b0029c9fe"
READER_ROLE_ID="acdd72a7-3385-48ef-bd42-f606fba81ae7"
ACR_PULL_ROLE_ID="7f951dda-4ed3-4680-a7ca-43fe172d538d"
STORAGE_BLOB_DATA_READER_ROLE_ID="2a2b9908-6ea1-4ae2-8e65-a410df84e7d1"
KEY_VAULT_SECRETS_USER_ROLE_ID="4633458b-17de-408a-b874-0445c86b69e6"

read -r RBAC_ASSIGNMENT_ID STATE_ASSIGNMENT_ID < <(
python3 - "$ENVIRONMENT" <<'PY'
import sys, uuid
env=sys.argv[1]
ns=uuid.UUID('a25d3a3b-e2f1-49cc-93df-8f4ec8a9d8cd')
for value in (f'iam-rbac-admin:{env}', f'iam-state:{env}'):
    print(uuid.uuid5(ns, value), end=' ')
print()
PY
)

SUB_SCOPE="/subscriptions/${SUBSCRIPTION_ID}"
STATE_RG_SCOPE="${SUB_SCOPE}/resourceGroups/${STATE_RG}"
STATE_STORAGE_SCOPE="${STATE_RG_SCOPE}/providers/Microsoft.Storage/storageAccounts/${STATE_STORAGE}"
STATE_CONTAINER_SCOPE="${STATE_STORAGE_SCOPE}/blobServices/default/containers/${STATE_CONTAINER}"
RBAC_ADMIN_ROLE_DEFINITION_ID="${SUB_SCOPE}/providers/Microsoft.Authorization/roleDefinitions/${RBAC_ADMIN_ROLE_ID}"
STATE_ROLE_DEFINITION_ID="${SUB_SCOPE}/providers/Microsoft.Authorization/roleDefinitions/${STORAGE_BLOB_DATA_CONTRIBUTOR_ROLE_ID}"
RESULT_FILE="${ENVIRONMENT}-iac-iam-capability-result.json"

ALLOWED_ROLE_IDS="${READER_ROLE_ID}, ${ACR_PULL_ROLE_ID}, ${STORAGE_BLOB_DATA_READER_ROLE_ID}, ${KEY_VAULT_SECRETS_USER_ROLE_ID}"
CONDITION="((!(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})) OR (@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${ALLOWED_ROLE_IDS}} AND @Request[Microsoft.Authorization/roleAssignments:PrincipalType] ForAnyOfAnyValues:StringEqualsIgnoreCase {'ServicePrincipal'})) AND ((!(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})) OR (@Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${ALLOWED_ROLE_IDS}} AND @Resource[Microsoft.Authorization/roleAssignments:PrincipalType] ForAnyOfAnyValues:StringEqualsIgnoreCase {'ServicePrincipal'}))"

log(){ printf '[iac-iam-%s] %s\n' "$ENVIRONMENT" "$*"; }
fail(){ printf '[iac-iam-%s][ERROR] %s\n' "$ENVIRONMENT" "$*" >&2; exit 1; }
arm(){ printf 'https://management.azure.com%s' "$1"; }
put_json(){ az rest --method put --url "$(arm "$1?api-version=$2")" --headers 'Content-Type=application/json' --body "$3" --output none; }
identity_field(){ az rest --method get --url "$(arm "${STATE_RG_SCOPE}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${IDENTITY_NAME}?api-version=2023-01-31")" --query "properties.$1" -o tsv; }

command -v az >/dev/null 2>&1 || fail "Azure CLI is required"
command -v python3 >/dev/null 2>&1 || fail "python3 is required"
az account show >/dev/null 2>&1 || fail "Azure CLI is not authenticated"
[[ "$(az account show --query tenantId -o tsv)" == "$TENANT_ID" ]] || fail "unexpected tenant"
az account set --subscription "$SUBSCRIPTION_ID"
[[ "$(az account show --query id -o tsv)" == "$SUBSCRIPTION_ID" ]] || fail "unexpected subscription"

python3 - "$CONDITION" "$RBAC_ADMIN_ROLE_ID" "$ALLOWED_ROLE_IDS" <<'PY'
import sys
condition, admin_role, allowed = sys.argv[1:]
assert admin_role == 'f58310d9-a9f6-439a-9e8d-f62e7b41a168'
assert "roleAssignments/write" in condition
assert "roleAssignments/delete" in condition
assert "RoleDefinitionId" in condition
assert "PrincipalType" in condition
assert "ServicePrincipal" in condition
for role_id in [x.strip() for x in allowed.split(',')]:
    assert role_id in condition
for forbidden in (
    '8e3af657-a8ff-443c-a75c-2fe8c4bcb635',
    'b24988ac-6180-42a0-ab88-20f7382dd24c',
    '18d7d88d-d35e-4fb5-a5c3-7773c20a72d9',
):
    assert forbidden not in condition
print('Conditioned IAM delegation contract valid.')
PY

log "Identity: ${IDENTITY_NAME} -> ${GITHUB_ENVIRONMENT}"
log "Delegated role: Role Based Access Control Administrator with ABAC condition"
log "Allowed target roles: Reader, AcrPull, Storage Blob Data Reader, Key Vault Secrets User"
log "Allowed target principal type: ServicePrincipal"

if [[ "$APPLY" -eq 0 ]]; then
  cat <<EOF
PLAN ONLY - no Azure mutation.
Planned mutations:
  1. Create/normalize dedicated ${ENVIRONMENT} IAM Apply UAMI and OIDC FIC.
  2. Assign Role Based Access Control Administrator with ABAC condition version 2.0.
  3. Condition permits only the four approved low-risk roles and ServicePrincipal targets.
  4. Assign Storage Blob Data Contributor only on the tfstate container.

Not granted through the condition: Owner, Contributor, User Access Administrator, RBAC Administrator, Network Contributor or arbitrary custom roles.
The InfrastructureRequest renderer additionally rejects subscription-root and authorization-resource target scopes.
EOF
  exit 0
fi

log "Registering Managed Identity provider"
az provider register --namespace Microsoft.ManagedIdentity --wait --output none

IDENTITY_BODY="$(printf '{"location":"%s","tags":{"managed_by":"iac-control-plane-bootstrap","environment":"%s","capability":"conditioned-iam"}}' "$LOCATION" "$ENVIRONMENT")"
put_json "${STATE_RG_SCOPE}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${IDENTITY_NAME}" "2023-01-31" "$IDENTITY_BODY"
CLIENT_ID="$(identity_field clientId)"
PRINCIPAL_ID="$(identity_field principalId)"
[[ -n "$CLIENT_ID" && -n "$PRINCIPAL_ID" ]] || fail "failed to resolve IAM UAMI IDs"

FIC_BODY="$(python3 - "$ISSUER" "$REPOSITORY" "$GITHUB_ENVIRONMENT" "$AUDIENCE" <<'PY'
import json, sys
issuer, repo, env, audience = sys.argv[1:]
print(json.dumps({'properties': {'issuer': issuer, 'subject': f'repo:{repo}:environment:{env}', 'audiences': [audience]}}))
PY
)"
put_json "${STATE_RG_SCOPE}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${IDENTITY_NAME}/federatedIdentityCredentials/${FIC_NAME}" "2024-11-30" "$FIC_BODY"

RBAC_BODY="$(python3 - "$PRINCIPAL_ID" "$RBAC_ADMIN_ROLE_DEFINITION_ID" "$CONDITION" <<'PY'
import json, sys
principal, role, condition = sys.argv[1:]
print(json.dumps({'properties': {
    'principalId': principal,
    'principalType': 'ServicePrincipal',
    'roleDefinitionId': role,
    'condition': condition,
    'conditionVersion': '2.0',
    'description': 'Enterprise IaC conditioned IAM delegation: approved roles to ServicePrincipal targets only.'
}}))
PY
)"
put_json "${SUB_SCOPE}/providers/Microsoft.Authorization/roleAssignments/${RBAC_ASSIGNMENT_ID}" "2022-04-01" "$RBAC_BODY"

STATE_BODY="$(python3 - "$PRINCIPAL_ID" "$STATE_ROLE_DEFINITION_ID" <<'PY'
import json, sys
principal, role = sys.argv[1:]
print(json.dumps({'properties': {'principalId': principal, 'principalType': 'ServicePrincipal', 'roleDefinitionId': role}}))
PY
)"
put_json "${STATE_CONTAINER_SCOPE}/providers/Microsoft.Authorization/roleAssignments/${STATE_ASSIGNMENT_ID}" "2022-04-01" "$STATE_BODY"

log "Verifying conditioned role assignment"
az rest --method get \
  --url "$(arm "${SUB_SCOPE}/providers/Microsoft.Authorization/roleAssignments/${RBAC_ASSIGNMENT_ID}?api-version=2022-04-01")" \
  --query '{principalId:properties.principalId,roleDefinitionId:properties.roleDefinitionId,conditionVersion:properties.conditionVersion,condition:properties.condition}' \
  -o json > /tmp/iac-iam-assignment.json

python3 - /tmp/iac-iam-assignment.json "$PRINCIPAL_ID" "$RBAC_ADMIN_ROLE_ID" "$ALLOWED_ROLE_IDS" <<'PY'
import json, sys
path, principal, admin_role, allowed = sys.argv[1:]
data=json.load(open(path))
assert data['principalId'] == principal
assert data['roleDefinitionId'].lower().endswith('/' + admin_role.lower())
assert data['conditionVersion'] == '2.0'
condition=data['condition']
assert "ServicePrincipal" in condition
for role in [x.strip() for x in allowed.split(',')]:
    assert role in condition
print('Effective IAM ABAC role assignment is constrained and valid.')
PY

cat > "$RESULT_FILE" <<EOF
{
  "status": "READY_FOR_IAC_IAM_GITHUB_BINDING",
  "environment": "${ENVIRONMENT}",
  "githubEnvironment": "${GITHUB_ENVIRONMENT}",
  "identityName": "${IDENTITY_NAME}",
  "clientId": "${CLIENT_ID}",
  "principalId": "${PRINCIPAL_ID}",
  "resourceId": "${STATE_RG_SCOPE}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${IDENTITY_NAME}",
  "delegatedRole": "Role Based Access Control Administrator",
  "delegatedRoleId": "${RBAC_ADMIN_ROLE_ID}",
  "conditionVersion": "2.0",
  "allowedPrincipalType": "ServicePrincipal",
  "allowedRoleDefinitionIds": [
    "${READER_ROLE_ID}",
    "${ACR_PULL_ROLE_ID}",
    "${STORAGE_BLOB_DATA_READER_ROLE_ID}",
    "${KEY_VAULT_SECRETS_USER_ROLE_ID}"
  ],
  "subscriptionRootTargetAllowedByRenderer": false,
  "ownerAllowed": false,
  "contributorAllowed": false,
  "userAccessAdministratorAllowed": false,
  "arbitraryRoleAssignmentAllowed": false,
  "stateRole": "Storage Blob Data Contributor",
  "stateScope": "container"
}
EOF
python3 -m json.tool "$RESULT_FILE" >/dev/null
log "IAM capability activation complete: $RESULT_FILE"
