module "resource_group" {
  source = "../../../modules/resource-group"
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

module "observability" {
  source = "../../../modules/observability"

  resource_group_name                  = module.resource_group.name
  location                             = module.resource_group.location
  log_analytics_name                   = var.log_analytics_name
  monitor_workspace_name               = var.monitor_workspace_name
  log_retention_days                   = var.log_retention_days
  daily_quota_gb                       = var.daily_quota_gb
  internet_ingestion_enabled           = var.internet_ingestion_enabled
  internet_query_enabled               = var.internet_query_enabled
  monitor_public_network_access_enabled = var.monitor_public_network_access_enabled
  tags                                 = var.tags
}
