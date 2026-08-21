terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

resource "azurerm_kubernetes_cluster" "main" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.name

  private_cluster_enabled = var.private_cluster_enabled
  network_policy          = var.network_policy

  role_based_access_control_enabled = var.azure_rbac_enabled
  workload_identity_enabled          = var.workload_identity_enabled
  oidc_issuer_enabled                = var.oidc_issuer_enabled

  default_node_pool {
    name                = "system"
    node_count          = var.node_count
    vm_size             = var.vm_size
    enable_auto_scaling = var.enable_auto_scaling
    min_count           = var.min_count
    max_count           = var.max_count
    availability_zones  = var.availability_zones
    os_disk_type        = "Managed"

    upgrade_settings {
      max_surge = var.max_surge
    }
  }

  identity {
    type = "SystemAssigned"
  }

  maintenance_window {
    allowed {
      day   = var.maintenance_window_day
      hours = [2]
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "workload" {
  count = var.enable_workload_node_pool ? 1 : 0

  name                  = "workload"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.workload_vm_size
  node_count            = var.workload_node_count

  enable_auto_scaling = true
  min_count           = var.workload_min_count
  max_count           = var.workload_max_count

  availability_zones = var.availability_zones
  mode               = "User"
  os_disk_type       = "Managed"

  lifecycle {
    prevent_destroy = true
  }
}
