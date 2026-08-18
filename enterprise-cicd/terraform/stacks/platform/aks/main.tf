module "resource_group" {
  source = "../../../modules/resource-group"

  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

module "aks" {
  source = "../../../modules/aks"

  name                           = var.cluster_name
  resource_group_name            = module.resource_group.name
  location                       = module.resource_group.location
  dns_prefix                     = var.dns_prefix
  kubernetes_version             = var.kubernetes_version
  sku_tier                       = "Standard"
  private_cluster_enabled        = var.private_cluster_enabled
  admin_group_object_ids         = var.admin_group_object_ids
  outbound_type                  = var.outbound_type
  service_cidr                   = var.service_cidr
  dns_service_ip                 = var.dns_service_ip
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  managed_prometheus_enabled     = var.managed_prometheus_enabled
  prometheus_annotations_allowed = var.prometheus_annotations_allowed
  prometheus_labels_allowed      = var.prometheus_labels_allowed
  tags                           = var.tags

  system_node_pool = {
    name                 = "system"
    vm_size              = var.system_vm_size
    vnet_subnet_id       = var.aks_subnet_id
    node_count           = var.system_min_count
    auto_scaling_enabled = true
    min_count            = var.system_min_count
    max_count            = var.system_max_count
    zones                = ["1", "2", "3"]
    max_pods             = 50
    os_disk_size_gb      = 128
  }
}

module "acr_pull" {
  source = "../../../modules/role-assignment"

  assignments = var.acr_id == null ? {} : {
    kubelet_acr_pull = {
      scope                = var.acr_id
      role_definition_name = "AcrPull"
      principal_id         = module.aks.kubelet_identity_object_id
      principal_type       = "ServicePrincipal"
      description          = "Allow AKS kubelet identity to pull immutable application images."
    }
  }
}
