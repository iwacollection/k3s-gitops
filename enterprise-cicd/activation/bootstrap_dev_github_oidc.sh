#!/usr/bin/env bash
set -euo pipefail

SUBSCRIPTION_ID="c12c3a36-99d8-4741-bcef-cd7df5d5cd4a"
TENANT_ID="a1c6a587-dc3b-40a5-9438-445d896bb5f2"
IDENTITY_RG="sub-test"
IDENTITY_NAME="k8s-test-gruop-uami"
EXPECTED_CLIENT_ID="cfb1ddc1-fd3b-4709-b4b0-4cccebaa58ad"
FIC_NAME="github-k3s-gitops-dev"
ISSUER="https://token.actions.githubusercontent.com"
SUBJECT="repo:iwacollection/k3s-gitops:environment:dev"
AUDIENCE="api://AzureADTokenExchange"

log() {
  printf '[activation] %s\n' "$*"
}

fail() {
  printf '[activation][ERROR] %s\n' "$*" >&2
  exit 1
}

command -v az >/dev/null 2>&1 || fail "Azure CLI (az) is required"

log "Checking current Azure login"
az account show >/dev/null 2>&1 || fail "Azure CLI is not logged in. Run: az login"

CURRENT_TENANT="$(az account show --query tenantId -o tsv)"
if [[ "$CURRENT_TENANT" != "$TENANT_ID" ]]; then
  fail "Current tenant is $CURRENT_TENANT, expected $TENANT_ID"
fi

log "Selecting subscription $SUBSCRIPTION_ID"
az account set --subscription "$SUBSCRIPTION_ID"

log "Validating existing user-assigned managed identity"
IDENTITY_JSON="$(az identity show \
  --resource-group "$IDENTITY_RG" \
  --name "$IDENTITY_NAME" \
  --subscription "$SUBSCRIPTION_ID" \
  -o json)"

ACTUAL_CLIENT_ID="$(jq -r '.clientId' <<<"$IDENTITY_JSON")"
ACTUAL_PRINCIPAL_ID="$(jq -r '.principalId' <<<"$IDENTITY_JSON")"
[[ "$ACTUAL_CLIENT_ID" == "$EXPECTED_CLIENT_ID" ]] || fail "Managed identity clientId mismatch: got $ACTUAL_CLIENT_ID"

log "Checking federated credential $FIC_NAME"
EXISTING="$(az identity federated-credential list \
  --identity-name "$IDENTITY_NAME" \
  --resource-group "$IDENTITY_RG" \
  --subscription "$SUBSCRIPTION_ID" \
  --query "[?name=='$FIC_NAME'] | [0]" \
  -o json)"

if [[ "$EXISTING" != "null" && -n "$EXISTING" ]]; then
  EXISTING_ISSUER="$(jq -r '.issuer // empty' <<<"$EXISTING")"
  EXISTING_SUBJECT="$(jq -r '.subject // empty' <<<"$EXISTING")"
  EXISTING_AUDIENCE="$(jq -r '.audiences[0] // empty' <<<"$EXISTING")"

  [[ "$EXISTING_ISSUER" == "$ISSUER" ]] || fail "Existing FIC issuer mismatch: $EXISTING_ISSUER"
  [[ "$EXISTING_SUBJECT" == "$SUBJECT" ]] || fail "Existing FIC subject mismatch: $EXISTING_SUBJECT"
  [[ "$EXISTING_AUDIENCE" == "$AUDIENCE" ]] || fail "Existing FIC audience mismatch: $EXISTING_AUDIENCE"
  log "Federated credential already exists and matches the DEV contract"
else
  log "Creating federated credential"
  az identity federated-credential create \
    --name "$FIC_NAME" \
    --identity-name "$IDENTITY_NAME" \
    --resource-group "$IDENTITY_RG" \
    --subscription "$SUBSCRIPTION_ID" \
    --issuer "$ISSUER" \
    --subject "$SUBJECT" \
    --audiences "$AUDIENCE" \
    -o none
fi

log "Verifying final federated credential"
az identity federated-credential show \
  --name "$FIC_NAME" \
  --identity-name "$IDENTITY_NAME" \
  --resource-group "$IDENTITY_RG" \
  --subscription "$SUBSCRIPTION_ID" \
  --query '{name:name,issuer:issuer,subject:subject,audiences:audiences}' \
  -o json

cat <<EOF
{
  "status": "READY_FOR_GITHUB_OIDC_RETEST",
  "subscriptionId": "$SUBSCRIPTION_ID",
  "tenantId": "$TENANT_ID",
  "identityName": "$IDENTITY_NAME",
  "clientId": "$ACTUAL_CLIENT_ID",
  "principalId": "$ACTUAL_PRINCIPAL_ID",
  "federatedCredential": "$FIC_NAME",
  "issuer": "$ISSUER",
  "subject": "$SUBJECT",
  "audience": "$AUDIENCE"
}
EOF
