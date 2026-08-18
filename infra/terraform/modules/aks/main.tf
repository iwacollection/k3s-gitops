// AKS module scaffold - fill in based on your needs
variable "resource_group_name" {}
variable "location" {}
variable "cluster_name" {}
variable "node_count" { default = 3 }

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name

  default_node_pool {
    name       = "agentpool"
    node_count = var.node_count
    vm_size    = "Standard_DS2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  addon_profile {
    oms_agent {
      enabled = false
    }
  }
}

output "kube_config" {
  value = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive = true
}
