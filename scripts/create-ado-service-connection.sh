#!/usr/bin/env bash
set -euo pipefail

# scripts/create-ado-service-connection.sh
# Creates an Azure RM service endpoint in Azure DevOps using the az devops CLI.
# Pre-reqs:
#  - az extension add --name azure-devops
#  - az devops configure --defaults organization=https://dev.azure.com/<ORG> project=<PROJECT>
#  - you have a Service Principal JSON (clientId/clientSecret/tenantId/subscriptionId)

if [ "$#" -lt 6 ]; then
  echo "Usage: $0 <service-connection-name> <subscription-id> <subscription-name> <tenant-id> <client-id> <client-secret>"
  echo "Example: $0 k3s-gitops-conn <sub-id> 'My Subscription' <tenant-id> <client-id> <client-secret>"
  exit 1
fi

SC_NAME="$1"
SUB_ID="$2"
SUB_NAME="$3"
TENANT_ID="$4"
CLIENT_ID="$5"
CLIENT_SECRET="$6"

# Create the service endpoint
az devops service-endpoint azurerm create \
  --name "$SC_NAME" \
  --azure-rm-subscription-id "$SUB_ID" \
  --azure-rm-subscription-name "$SUB_NAME" \
  --azure-rm-tenant-id "$TENANT_ID" \
  --azure-rm-service-principal-id "$CLIENT_ID" \
  --azure-rm-service-principal-secret "$CLIENT_SECRET" \
  --output json

echo "Service connection '$SC_NAME' created (or updated)."

# Note: You may need to give the pipeline permission to use the service connection via the Azure DevOps UI (Project settings -> Service connections -> <name> -> Security -> Grant access to all pipelines)
