resource "azurerm_postgresql_flexible_server" "this" {
  name                   = var.name
  resource_group_name    = var.resource_group_name
  location               = var.location
  version                = var.postgres_version
  administrator_login    = var.admin_username
  administrator_password = var.admin_password

  sku_name = var.sku_name
  zone     = var.zone

  storage_mb = var.storage_mb

  backup_retention_days        = var.backup_retention_days
  public_network_access_enabled = var.public_network_access_enabled
}
