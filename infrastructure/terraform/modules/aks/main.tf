resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix

  kubernetes_version        = var.kubernetes_version
  sku_tier                  = "Free"
  private_cluster_enabled   = var.private_cluster_enabled
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name                        = "system"
    node_count                  = var.node_count
    vm_size                     = var.vm_size
    vnet_subnet_id              = var.subnet_id
    os_disk_size_gb             = 64
    zones                       = var.availability_zones
    temporary_name_for_rotation = "systemtmp"

    # Keep the existing AKS upgrade defaults explicit so adding availability
    # zones does not introduce unrelated pool drift during the rotation.
    upgrade_settings {
      max_surge                     = "10%"
      drain_timeout_in_minutes      = 0
      node_soak_duration_in_minutes = 0
    }
  }

  identity {
    type = "SystemAssigned"
  }

  role_based_access_control_enabled = true

  network_profile {
    network_plugin = "azure"
    outbound_type  = "userAssignedNATGateway"
    service_cidr   = var.service_cidr
    dns_service_ip = var.dns_service_ip
  }

  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "workload" {
  name                  = "workload"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = var.user_vm_size
  node_count            = var.user_node_count
  vnet_subnet_id        = var.subnet_id
  os_disk_size_gb       = 64
  mode                  = "User"
  zones                 = var.availability_zones

  node_labels = {
    "workload" = "general"
  }
}

output "id" {
  value = azurerm_kubernetes_cluster.this.id
}

output "name" {
  value = azurerm_kubernetes_cluster.this.name
}

output "fqdn" {
  value = azurerm_kubernetes_cluster.this.fqdn
}

output "kubelet_object_id" {
  value = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}

output "oidc_issuer_url" {
  value = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "workload_node_pool_id" {
  value = azurerm_kubernetes_cluster_node_pool.workload.id
}
