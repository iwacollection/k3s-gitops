module "aks_observability" {
  source = "../../../modules/aks-observability"

  cluster_id                    = var.cluster_id
  cluster_name                  = var.cluster_name
  cluster_location              = var.cluster_location
  resource_group_name           = var.cluster_resource_group_name
  log_analytics_workspace_id    = var.log_analytics_workspace_id
  monitor_workspace_id          = var.monitor_workspace_id
  monitor_workspace_location    = var.monitor_workspace_location
  container_collection_interval = var.container_collection_interval
  namespace_filtering_mode      = var.namespace_filtering_mode
  excluded_namespaces           = var.excluded_namespaces
  tags                          = var.tags
}
