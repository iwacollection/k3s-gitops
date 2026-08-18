data "azurerm_subnet" "private_endpoint" {
  name                 = var.private_endpoint_subnet_name
  virtual_network_name = var.virtual_network_name
  resource_group_name  = var.network_resource_group_name
}

data "azurerm_private_dns_zone" "redis" {
  name                = var.private_dns_zone_name
  resource_group_name = var.network_resource_group_name
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
