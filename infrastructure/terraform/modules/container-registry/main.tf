resource "azurerm_container_registry" "this" {
  name                          = var.name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = var.sku
  admin_enabled                 = false
  public_network_access_enabled = var.public_network_access_enabled

  # AzureRM 4.x: trust_policy block/content_trust_enabled were replaced.
  trust_policy_enabled = true

  # AzureRM 4.x: retention_policy block was replaced by this property.
  retention_policy_in_days = 30

  # Premium registry geo replication baseline
  dynamic "georeplications" {
    for_each = var.geo_replication_locations
    content {
      location = georeplications.value
    }
  }
}

output "id" {
  value = azurerm_container_registry.this.id
}

output "login_server" {
  value = azurerm_container_registry.this.login_server
}

output "name" {
  value = azurerm_container_registry.this.name
}
