resource "azurerm_log_analytics_workspace" "this" {
  name                         = var.log_analytics_name
  location                     = var.location
  resource_group_name          = var.resource_group_name
  sku                          = "PerGB2018"
  retention_in_days            = var.log_retention_days
  daily_quota_gb               = var.daily_quota_gb
  local_authentication_enabled = false
  internet_ingestion_enabled   = var.internet_ingestion_enabled
  internet_query_enabled       = var.internet_query_enabled
  tags                         = var.tags
}

resource "azurerm_monitor_workspace" "this" {
  name                          = var.monitor_workspace_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  public_network_access_enabled = var.monitor_public_network_access_enabled
  tags                          = var.tags
}
