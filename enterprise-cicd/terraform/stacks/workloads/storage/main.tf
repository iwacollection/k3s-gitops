locals {
  environment                 = lookup(var.tags, "environment", "dev")
  network_resource_group_name = coalesce(var.network_resource_group_name, "rg-platform-network-${local.environment}")
  virtual_network_name        = coalesce(var.virtual_network_name, "vnet-platform-${local.environment}")
}

data "azurerm_subnet" "private_endpoint" {
  name                 = var.private_endpoint_subnet_name
  virtual_network_name = local.virtual_network_name
  resource_group_name  = local.network_resource_group_name
}

data "azurerm_private_dns_zone" "storage" {
  name                = var.private_dns_zone_name
  resource_group_name = local.network_resource_group_name
}

module "resource_group" {
  source = "../../../modules/resource-group"

  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

module "storage" {
  source = "../../../modules/storage-account"

  name                          = var.storage_account_name
  resource_group_name           = module.resource_group.name
  location                      = module.resource_group.location
  replication_type              = var.replication_type
  access_tier                   = var.access_tier
  public_network_access_enabled = var.public_network_access_enabled
  shared_key_access_enabled     = false
  blob_versioning_enabled       = var.blob_versioning_enabled
  delete_retention_days         = var.delete_retention_days
  tags                          = var.tags
}

module "private_endpoint" {
  source = "../../../modules/private-endpoint"

  name                           = "pe-${var.storage_account_name}-blob"
  location                       = var.location
  resource_group_name            = module.resource_group.name
  subnet_id                      = data.azurerm_subnet.private_endpoint.id
  private_connection_resource_id = module.storage.id
  subresource_names              = ["blob"]
  private_dns_zone_ids           = [data.azurerm_private_dns_zone.storage.id]
  tags                           = var.tags
}

module "resource_lock" {
  count  = local.environment == "prod" ? 1 : 0
  source = "../../../modules/resource-lock"

  name       = "lock-${var.storage_account_name}"
  scope      = module.storage.id
  lock_level = "CanNotDelete"
  notes      = "Production storage resource protected by enterprise IaC policy."
}
