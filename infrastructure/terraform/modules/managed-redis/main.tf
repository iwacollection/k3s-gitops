resource "azurerm_redis_cache" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name

  capacity = var.capacity
  family   = var.sku_name == "Premium" ? "P" : "C"
  sku_name = var.sku_name

  non_ssl_port_enabled = false
  minimum_tls_version  = "1.2"
}
