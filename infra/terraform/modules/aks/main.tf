provider "azurerm" {
  features {}
}

data "azurerm_subscription" "current" {}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name

  dns_prefix = var.dns_prefix != null ? var.dns_prefix : var.cluster_name

  default_node_pool {
    name       = "agentpool"
    node_count = var.node_count
    vm_size    = var.node_vm_size
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = var.network_plugin
    service_cidr      = var.service_cidr
    dns_service_ip    = var.dns_service_ip
    docker_bridge_cidr = var.docker_bridge_cidr
  }

  lifecycle {
    ignore_changes = ["default_node_pool[0].node_count"]
  }

  role_based_access_control {
    enabled = true
  }

  tags = {
    created_by = "terraform"
    environment = "${var.resource_group_name}"
  }

  dynamic "kubernetes_version" {
    for_each = var.kubernetes_version == null ? [] : [var.kubernetes_version]
    content {
      kubernetes_version = var.kubernetes_version
    }
  }
}

# If an ACR resource id is provided, assign AcrPull to the cluster's kubelet identity
resource "azurerm_role_assignment" "acr_pull" {
  count = var.acr_resource_id == "" ? 0 : 1

  scope                = var.acr_resource_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

output "kube_config_raw" {
  description = "Raw kubeconfig (sensitive)"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}

output "cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "kubelet_identity_object_id" {
  value = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}
