resource "azurerm_managed_redis" "this" {
  name                      = var.name
  resource_group_name       = var.resource_group_name
  location                  = var.location
  sku_name                  = var.sku_name
  high_availability_enabled = var.high_availability_enabled
  public_network_access     = var.public_network_access
  tags                      = var.tags

  default_database {
    access_keys_authentication_enabled             = false
    client_protocol                                = "Encrypted"
    clustering_policy                              = var.clustering_policy
    eviction_policy                                = var.eviction_policy
    persistence_redis_database_backup_frequency    = var.persistence_redis_database_backup_frequency
  }
}
