#!/usr/bin/env bash
set -euo pipefail

# scripts/create-ado-variable-group.sh
# Creates an Azure DevOps variable group (non-secret variables). For secret variables, create via UI or REST API.
# Pre-reqs:
#  - az extension add --name azure-devops
#  - az devops configure --defaults organization=https://dev.azure.com/<ORG> project=<PROJECT>

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <variable-group-name>"
  echo "Example: $0 k3s-gitops-vars"
  exit 1
fi

VG_NAME="$1"

# Example variables - update values or leave blank to set later in UI
az pipelines variable-group create --name "$VG_NAME" \
  --variables "AZURE_SUBSCRIPTION_ID=" "AZURE_TENANT_ID=" "AZURE_CLIENT_ID=" "AZURE_CLIENT_SECRET=" "TFSTATE_STORAGE_ACCOUNT=" "TFSTATE_CONTAINER=tfstate" "TFSTATE_RESOURCE_GROUP=" "ACR_NAME=" "ACR_LOGIN_SERVER=" "TF_AKS_RG=" "TF_AKS_CLUSTER=" \
  --authorize true

echo "Variable group '$VG_NAME' created (check and update secret vars via UI)."
