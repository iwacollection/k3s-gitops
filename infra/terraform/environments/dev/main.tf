# Root environment for dev - creates resource group, ACR and AKS

provider "azurerm" {
  features {}
}

variable "location" {
  type = string
  default = "eastus"
}

variable "rg_name" {
  type = string
  default = "rg-k3s-gitops-dev"
}

resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.location
  tags = {
    environment = "dev"
    managed_by  = "terraform"
  }
}

module "acr" {
  source = "../modules/acr"

  acr_name = "k3sgitopsacrdev"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
}

module "aks" {
  source = "../modules/aks"

  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  cluster_name = "k3s-gitops-dev-aks"
  node_count = 2
  node_vm_size = "Standard_DS2_v2"
  dns_prefix = "k3s-gitops-dev"
  acr_resource_id = module.acr.acr_resource_id
}

output "acr_login" {
  value = module.acr.acr_login_server
}

output "aks_cluster_name" {
  value = module.aks.cluster_name
}

output "aks_kubeconfig" {
  value     = module.aks.kube_config_raw
  sensitive = true
}
