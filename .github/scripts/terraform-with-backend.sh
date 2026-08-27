#!/usr/bin/env bash
set -euo pipefail

: "${AZURE_SUBSCRIPTION_ID:?AZURE_SUBSCRIPTION_ID is required}"

TF_ROOT="${TF_ROOT:-infrastructure/terraform/environments/production}"
STATE_RG="${TF_STATE_RESOURCE_GROUP:-rg-platform-cicd}"
STATE_CONTAINER="${TF_STATE_CONTAINER:-tfstate}"
STATE_KEY_NAME="${TF_STATE_KEY:-k3s-production.tfstate}"

SUB_COMPACT="${AZURE_SUBSCRIPTION_ID//-/}"
STATE_ACCOUNT="${TF_STATE_ACCOUNT:-stk3stfstate${SUB_COMPACT:0:12}}"
STATE_ACCOUNT="${STATE_ACCOUNT:0:24}"

az group show --name "$STATE_RG" --output none
az storage account show \
  --resource-group "$STATE_RG" \
  --name "$STATE_ACCOUNT" \
  --output none

STATE_ACCESS_KEY="$(az storage account keys list \
  --resource-group "$STATE_RG" \
  --account-name "$STATE_ACCOUNT" \
  --query '[0].value' \
  --output tsv)"

test -n "$STATE_ACCESS_KEY"
echo "::add-mask::$STATE_ACCESS_KEY"
export ARM_ACCESS_KEY="$STATE_ACCESS_KEY"

terraform -chdir="$TF_ROOT" init \
  -reconfigure \
  -input=false \
  -lockfile=readonly \
  -backend-config="resource_group_name=${STATE_RG}" \
  -backend-config="storage_account_name=${STATE_ACCOUNT}" \
  -backend-config="container_name=${STATE_CONTAINER}" \
  -backend-config="key=${STATE_KEY_NAME}"

cd "$TF_ROOT"
"$@"
