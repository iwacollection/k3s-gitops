locals {
  environment          = lookup(var.tags, "environment", "dev")
  bindings             = jsondecode(file("${path.root}/../../../../contracts/environment-bindings.json"))
  diagnostic_contracts = jsondecode(file("${path.root}/../../../../contracts/diagnostic-categories.json"))
  environment_binding  = local.bindings.environments[local.environment]
  diagnostic_contract  = local.diagnostic_contracts.services["key-vault"]
}

data "azurerm_subnet" "private_endpoint" {
  name                 = var.private_endpoint_subnet_name
  virtual_network_name = var.virtual_network_name
  resource_group_name  = var.network_resource_group_name
}

data "azurerm_private_dns_zone" "key_vault" {
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

module "key_vault" {
  source = "../../../modules/key-vault"

  name                          = var.key_vault_name
  resource_group_name           = module.resource_group.name
  location                      = module.resource_group.location
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = var.sku_name
  purge_protection_enabled      = var.purge_protection_enabled
  soft_delete_retention_days    = var.soft_delete_retention_days
  public_network_access_enabled = var.public_network_access_enabled
  tags                          = var.tags
}

module "private_endpoint" {
  source = "../../../modules/private-endpoint"

  name                           = "pe-${var.key_vault_name}"
  location                       = var.location
  resource_group_name            = module.resource_group.name
  subnet_id                      = data.azurerm_subnet.private_endpoint.id
  private_connection_resource_id = module.key_vault.id
  subresource_names              = ["vault"]
  private_dns_zone_ids           = [data.azurerm_private_dns_zone.key_vault.id]
  tags                           = var.tags
}

module "diagnostic_setting" {
  source = "../../../modules/diagnostic-setting"

  name                       = "diag-${var.key_vault_name}"
  target_resource_id         = module.key_vault.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.platform.id
  log_categories             = toset(local.diagnostic_contract.logCategories)
  log_category_groups        = toset(local.diagnostic_contract.logCategoryGroups)
  metric_categories          = toset(local.diagnostic_contract.metricCategories)
}

module "resource_lock" {
  count  = local.environment == "prod" ? 1 : 0
  source = "../../../modules/resource-lock"

  name       = "lock-${var.key_vault_name}"
  scope      = module.key_vault.id
  lock_level = "CanNotDelete"
  notes      = "Production Key Vault protected by enterprise IaC policy."
}
