#!/usr/bin/env bash
set -euo pipefail

# scripts/setup-azure.sh
# Small helper to create RG, storage account + container (for Terraform state) and optional ACR.
# Run locally after 'az login' and 'az account set --subscription <SUB_ID>'

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <resource-group-name> <location> [tfstate-storage-account]"
  echo "Example: $0 rg-k3s-gitops-dev eastus tfstateacctk3s"
  exit 1
fi

RG_NAME="$1"
LOCATION="$2"
TFSTATE_SA="${3:-}" # optional

echo "Using Resource Group: $RG_NAME in $LOCATION"

# Create resource group
az group create -n "$RG_NAME" -l "$LOCATION"

# Create storage account for terraform state if provided
if [ -n "$TFSTATE_SA" ]; then
  echo "Creating storage account $TFSTATE_SA in RG $RG_NAME"
  az storage account create -n "$TFSTATE_SA" -g "$RG_NAME" -l "$LOCATION" --sku Standard_LRS
  echo "Creating container 'tfstate'"
  az storage container create --name tfstate --account-name "$TFSTATE_SA"
  echo "Terraform backend info: storage_account_name=$TFSTATE_SA, container_name=tfstate, key=k3s-gitops.terraform.tfstate" 
fi

# Optional: create ACR
read -r -p "Create an Azure Container Registry in this RG? (y/N) " CREATE_ACR
if [[ "$CREATE_ACR" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  read -r -p "ACR name (must be globally unique): " ACR_NAME
  az acr create -n "$ACR_NAME" -g "$RG_NAME" --sku Basic
  echo "Created ACR: ${ACR_NAME}.azurecr.io"i

# Create a Service Principal for CI (note: this grants Contributor on the subscription - adjust scope for least privilege)
read -r -p "Create a Service Principal for CI (Contributor on subscription)? (y/N) " CREATE_SP
if [[ "$CREATE_SP" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  read -r -p "Subscription ID for SP scope (press Enter to use current): " SUB_ID
  if [ -z "$SUB_ID" ]; then
    SUB_ID=$(az account show --query id -o tsv)
  fi
  echo "Creating SP with Contributor on subscription $SUB_ID"
  SP_JSON=$(az ad sp create-for-rbac --name "sp-k3s-gitops-$(date +%s)" --role Contributor --scopes "/subscriptions/${SUB_ID}" --sdk-auth)
  echo "Service Principal JSON (store securely):"
  echo "$SP_JSON"
  echo "Use values clientId/clientSecret/tenantId/subscriptionId when creating Azure DevOps Service Connection or storing pipeline secrets."
fi

echo "Done."
