resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix

  kubernetes_version        = var.kubernetes_version
  sku_tier                  = "Standard"
  private_cluster_enabled   = true
  local_account_disabled    = true
  oidc_issuer_enabled       = true
  workload_identity_enabled = true
  azure_policy_enabled      = true
  automatic_channel_upgrade = "stable"

  default_node_pool {
    name                         = "system"
    node_count                   = var.node_count
    vm_size                      = var.vm_size
    vnet_subnet_id               = var.subnet_id
    os_disk_size_gb              = 64
    os_sku                       = "AzureLinux"
    zones                        = var.availability_zones
    max_pods                     = 50
    only_critical_addons_enabled = true
    temporary_name_for_rotation  = "systemtmp"

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

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
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
  max_pods              = 50

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
