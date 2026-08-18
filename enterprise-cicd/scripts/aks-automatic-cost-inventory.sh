#!/usr/bin/env bash

# Read-only AKS Automatic / cost-oriented inventory.
# No Azure resources are created, modified, scaled, stopped, or deleted.

set -u

LOG="${1:-azure_aks_automatic_cost_inventory.log}"
RG="${AKS_RESOURCE_GROUP:-group-test}"
CLUSTER="${AKS_CLUSTER_NAME:-k8s-test-cicd}"
API_VERSION="2026-04-01"

(
  {
    echo "========================================="
    echo " AKS AUTOMATIC + COST INVENTORY - READ ONLY"
    echo "========================================="

    SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
    CLUSTER_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG}/providers/Microsoft.ContainerService/managedClusters/${CLUSTER}"

    echo
    echo "[1] CURRENT AZURE CONTEXT"
    az account show --query '{subscription:name,state:state}' -o table

    echo
    echo "[2] MODERN ARM VIEW (bypasses old az aks field mapping)"
    az rest \
      --method get \
      --url "https://management.azure.com${CLUSTER_ID}?api-version=${API_VERSION}" \
      --query '{
        name:name,
        location:location,
        sku:sku,
        kubernetesVersion:properties.kubernetesVersion,
        provisioningState:properties.provisioningState,
        hostedSystemProfile:properties.hostedSystemProfile,
        nodeProvisioningProfile:properties.nodeProvisioningProfile,
        agentPoolProfiles:properties.agentPoolProfiles,
        networkProfile:properties.networkProfile,
        identity:identity
      }' \
      -o yaml

    echo
    echo "[3] KUBERNETES CREDENTIALS"
    az aks get-credentials \
      --resource-group "$RG" \
      --name "$CLUSTER" \
      --overwrite-existing \
      >/dev/null
    echo "credentials: configured"

    echo
    echo "[4] KUBERNETES NODES"
    kubectl get nodes -o wide

    echo
    echo "[5] NODE LABELS / INSTANCE TYPES"
    kubectl get nodes \
      -L node.kubernetes.io/instance-type,kubernetes.azure.com/agentpool,karpenter.sh/nodepool \
      -o wide

    echo
    echo "[6] NON-SYSTEM WORKLOADS"
    kubectl get pods -A \
      --field-selector=status.phase=Running \
      -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,NODE:.spec.nodeName' \
      | grep -vE '^(kube-system|gatekeeper-system|azure-arc|NAMESPACE)' \
      || true

    echo
    echo "[7] NODE RESOURCE GROUP"
    NODE_RG="$(az aks show --resource-group "$RG" --name "$CLUSTER" --query nodeResourceGroup -o tsv)"
    echo "$NODE_RG"

    echo
    echo "[8] BILLING-RELEVANT RESOURCE TYPES"
    az resource list \
      --resource-group "$NODE_RG" \
      --query '[].{name:name,type:type,kind:kind,sku:sku.name,location:location}' \
      -o table

    echo
    echo "[9] COMPUTE RESOURCES"
    az resource list \
      --resource-group "$NODE_RG" \
      --resource-type Microsoft.Compute/virtualMachineScaleSets \
      --query '[].{name:name,location:location,sku:sku.name,capacity:sku.capacity}' \
      -o table || true

    echo
    echo "[10] PUBLIC IP RESOURCES"
    az network public-ip list \
      --resource-group "$NODE_RG" \
      --query '[].{name:name,sku:sku.name,allocation:publicIPAllocationMethod,ip:ipAddress}' \
      -o table || true

    echo
    echo "[11] LOAD BALANCERS"
    az network lb list \
      --resource-group "$NODE_RG" \
      --query '[].{name:name,sku:sku.name}' \
      -o table || true

    echo
    echo "========================================="
    echo " INVENTORY FINISHED"
    echo "========================================="
  } 2>&1 | tee "$LOG"
)
