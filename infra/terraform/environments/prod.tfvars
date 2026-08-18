# Example production variables file (replace placeholders)

location = "eastus"
rg_name = "rg-k3s-gitops-prod"

# Adjust names to be globally unique
acr_name = "k3sgitopsacrprod"

# AKS params (can be tuned)
cluster_name = "k3s-gitops-prod-aks"
node_count = 3
node_vm_size = "Standard_DS3_v2"
