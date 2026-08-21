resource "azurerm_postgresql_flexible_server" "main" {
  name                   = var.name
  resource_group_name    = var.resource_group_name
  location               = var.location
  version                = "16"
  administrator_login     = var.admin_username
  administrator_password = var.admin_password
  storage_mb             = 32768
  sku_name               = "B_Standard_B1ms"

  backup_retention_days = 7

  lifecycle {
    prevent_destroy = true
  }
}
