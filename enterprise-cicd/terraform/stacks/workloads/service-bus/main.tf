locals {
  environment          = lookup(var.tags, "environment", "dev")
  bindings             = jsondecode(file("${path.root}/../../../../contracts/environment-bindings.json"))
  diagnostic_contracts = jsondecode(file("${path.root}/../../../../contracts/diagnostic-categories.json"))
  environment_binding  = local.bindings.environments[local.environment]
  diagnostic_contract  = local.diagnostic_contracts.services["service-bus"]
}

data "azurerm_subnet" "private_endpoint" {
  name                 = var.private_endpoint_subnet_name
  virtual_network_name = var.virtual_network_name
  resource_group_name  = var.network_resource_group_name
}

data "azurerm_private_dns_zone" "service_bus" {
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

module "service_bus" {
  source = "../../../modules/service-bus"

  name                          = var.service_bus_name
  resource_group_name           = module.resource_group.name
  location                      = module.resource_group.location
  sku                           = var.sku
  capacity                      = var.capacity
  public_network_access_enabled = var.public_network_access_enabled
  tags                          = var.tags
}

module "private_endpoint" {
  source = "../../../modules/private-endpoint"

  name                           = "pe-${var.service_bus_name}"
  location                       = var.location
  resource_group_name            = module.resource_group.name
  subnet_id                      = data.azurerm_subnet.private_endpoint.id
  private_connection_resource_id = module.service_bus.id
  subresource_names              = ["namespace"]
  private_dns_zone_ids           = [data.azurerm_private_dns_zone.service_bus.id]
  tags                           = var.tags
}

module "diagnostic_setting" {
  source = "../../../modules/diagnostic-setting"

  name                       = "diag-${var.service_bus_name}"
  target_resource_id         = module.service_bus.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.platform.id
  log_categories             = toset(local.diagnostic_contract.logCategories)
  log_category_groups        = toset(local.diagnostic_contract.logCategoryGroups)
  metric_categories          = toset(local.diagnostic_contract.metricCategories)
}

module "resource_lock" {
  count  = local.environment == "prod" ? 1 : 0
  source = "../../../modules/resource-lock"

  name       = "lock-${var.service_bus_name}"
  scope      = module.service_bus.id
  lock_level = "CanNotDelete"
  notes      = "Production Service Bus namespace protected by enterprise IaC policy."
}
