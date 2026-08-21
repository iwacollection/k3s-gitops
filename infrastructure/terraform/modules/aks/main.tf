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
    name       = "system"
    node_count = var.node_count
    vm_size    = var.vm_size
  }

  identity {
    type = "SystemAssigned"
  }

  lifecycle {
    prevent_destroy = true
  }
}
