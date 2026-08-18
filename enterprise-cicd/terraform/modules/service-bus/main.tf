resource "azurerm_servicebus_namespace" "this" {
  name                          = var.name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku                           = var.sku
  capacity                      = var.sku == "Premium" ? var.capacity : 0
  local_auth_enabled            = false
  public_network_access_enabled = var.public_network_access_enabled
  minimum_tls_version           = "1.2"
  tags                          = var.tags
}
