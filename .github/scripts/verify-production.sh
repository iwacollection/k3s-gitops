#!/usr/bin/env bash
set -euo pipefail

RG="${AZURE_WORKLOAD_RESOURCE_GROUP:-rg-k3s-production}"

az network vnet show --resource-group "$RG" --name k3s-production-vnet --output none
az network nsg show --resource-group "$RG" --name k3s-production-aks-nsg --output none
az network nat gateway show --resource-group "$RG" --name k3s-production-nat --output none
az aks show --resource-group "$RG" --name k3s-production-aks --output none
az aks nodepool show --resource-group "$RG" --cluster-name k3s-production-aks --name system --output none
az aks nodepool show --resource-group "$RG" --cluster-name k3s-production-aks --name workload --output none
az network lb show --resource-group "$RG" --name k3s-production-lb --output none
az redis show --resource-group "$RG" --name k3s-production-redis --output none
az postgres flexible-server show --resource-group "$RG" --name k3s-production-postgres --output none
az monitor log-analytics workspace show --resource-group "$RG" --workspace-name k3s-production-law --output none

ACR_NAME="$(az acr list --resource-group "$RG" --query "[?starts_with(name, 'k3sprodacr')].name | [0]" --output tsv)"
KV_NAME="$(az keyvault list --resource-group "$RG" --query "[?starts_with(name, 'k3s-prod-kv-')].name | [0]" --output tsv)"
test -n "$ACR_NAME"
test -n "$KV_NAME"

az network private-endpoint show --resource-group "$RG" --name k3s-production-acr-pe --output none
az network private-endpoint show --resource-group "$RG" --name k3s-production-kv-pe --output none
az network private-endpoint show --resource-group "$RG" --name k3s-production-redis-pe --output none
az network private-endpoint show --resource-group "$RG" --name k3s-production-postgres-pe --output none

KUBELET_OBJECT_ID="$(az aks show \
  --resource-group "$RG" \
  --name k3s-production-aks \
  --query identityProfile.kubeletidentity.objectId \
  --output tsv)"
ACR_ID="$(az acr show --resource-group "$RG" --name "$ACR_NAME" --query id --output tsv)"

test "$(az role assignment list \
  --assignee "$KUBELET_OBJECT_ID" \
  --scope "$ACR_ID" \
  --query "[?roleDefinitionName=='AcrPull'] | length(@)" \
  --output tsv)" -ge 1

az aks get-credentials \
  --resource-group "$RG" \
  --name k3s-production-aks \
  --admin \
  --overwrite-existing

kubectl wait --for=condition=Ready nodes --all --timeout=10m
kubectl get nodes -L agentpool,topology.kubernetes.io/zone
