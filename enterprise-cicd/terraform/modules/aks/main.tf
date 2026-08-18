resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier

  private_cluster_enabled             = var.private_cluster_enabled
  private_cluster_public_fqdn_enabled = false
  local_account_disabled              = true
  role_based_access_control_enabled   = true
  oidc_issuer_enabled                 = true
  workload_identity_enabled           = true
  azure_policy_enabled                = var.azure_policy_enabled
  automatic_upgrade_channel           = var.automatic_upgrade_channel
  node_os_upgrade_channel             = var.node_os_upgrade_channel

  default_node_pool {
    name                         = var.system_node_pool.name
    vm_size                      = var.system_node_pool.vm_size
    vnet_subnet_id               = var.system_node_pool.vnet_subnet_id
    node_count                   = var.system_node_pool.node_count
    auto_scaling_enabled         = var.system_node_pool.auto_scaling_enabled
    min_count                    = var.system_node_pool.auto_scaling_enabled ? var.system_node_pool.min_count : null
    max_count                    = var.system_node_pool.auto_scaling_enabled ? var.system_node_pool.max_count : null
    zones                        = var.system_node_pool.zones
    max_pods                     = var.system_node_pool.max_pods
    only_critical_addons_enabled = true
    os_disk_size_gb              = var.system_node_pool.os_disk_size_gb
    type                         = "VirtualMachineScaleSets"
  }

  identity {
    type = "SystemAssigned"
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled     = true
    admin_group_object_ids = var.admin_group_object_ids
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = var.network_policy
    outbound_type     = var.outbound_type
    service_cidr      = var.service_cidr
    dns_service_ip    = var.dns_service_ip
    load_balancer_sku = "standard"
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  dynamic "oms_agent" {
    for_each = var.log_analytics_workspace_id == null ? [] : [var.log_analytics_workspace_id]
    content {
      log_analytics_workspace_id      = oms_agent.value
      msi_auth_for_monitoring_enabled = true
    }
  }

  dynamic "monitor_metrics" {
    for_each = var.managed_prometheus_enabled ? [1] : []
    content {
      annotations_allowed = var.prometheus_annotations_allowed
      labels_allowed      = var.prometheus_labels_allowed
    }
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [default_node_pool[0].node_count]
  }
}
