locals {
  environment          = lookup(var.tags, "environment", "dev")
  bindings             = jsondecode(file("${path.root}/../../../../contracts/environment-bindings.json"))
  diagnostic_contracts = jsondecode(file("${path.root}/../../../../contracts/diagnostic-categories.json"))
  environment_binding  = local.bindings.environments[local.environment]
  diagnostic_contract  = local.diagnostic_contracts.services["managed-redis-database"]
}

data "azurerm_subnet" "private_endpoint" {
  name                 = var.private_endpoint_subnet_name
  virtual_network_name = var.virtual_network_name
  resource_group_name  = var.network_resource_group_name
}

data "azurerm_private_dns_zone" "redis" {
  name                = var.private_dns_zone_name
  resource_group_name = var.network_resource_group_name
}

data "azurerm_log_analytics_workspace" "platform" {
  name                = local.environment_binding.observability.logAnalyticsWorkspace
  resource_group_name = local.environment_binding.observability.resourceGroup
}

module "resource_group" {
  source = "../../../modules/resource-group"

  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

module "redis" {
  source = "../../../modules/managed-redis"

  name                                        = var.redis_name
  resource_group_name                         = module.resource_group.name
  location                                    = module.resource_group.location
  sku_name                                    = var.sku_name
  high_availability_enabled                   = var.high_availability_enabled
  public_network_access                       = var.public_network_access
  clustering_policy                           = var.clustering_policy
  eviction_policy                             = var.eviction_policy
  persistence_redis_database_backup_frequency = var.persistence_redis_database_backup_frequency
  tags                                        = var.tags
}

module "private_endpoint" {
  source = "../../../modules/private-endpoint"

  name                           = "pe-${var.redis_name}"
  location                       = var.location
  resource_group_name            = module.resource_group.name
  subnet_id                      = data.azurerm_subnet.private_endpoint.id
  private_connection_resource_id = module.redis.id
  subresource_names              = ["redisEnterprise"]
  private_dns_zone_ids           = [data.azurerm_private_dns_zone.redis.id]
  tags                           = var.tags
}

module "diagnostic_setting" {
  source = "../../../modules/diagnostic-setting"

  name                       = "diag-${var.redis_name}-database"
  target_resource_id         = "${module.redis.id}/databases/default"
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.platform.id
  log_categories             = toset(local.diagnostic_contract.logCategories)
  log_category_groups        = toset(local.diagnostic_contract.logCategoryGroups)
  metric_categories          = toset(local.diagnostic_contract.metricCategories)
}

module "resource_lock" {
  count  = local.environment == "prod" ? 1 : 0
  source = "../../../modules/resource-lock"

  name       = "lock-${var.redis_name}"
  scope      = module.redis.id
  lock_level = "CanNotDelete"
  notes      = "Production Azure Managed Redis protected by enterprise IaC policy."
}
