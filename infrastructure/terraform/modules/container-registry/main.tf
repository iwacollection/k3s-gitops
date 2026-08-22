resource "azurerm_container_registry" "this" {
  name                          = var.name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = var.sku
  admin_enabled                 = false
  public_network_access_enabled = var.public_network_access_enabled

  zone_redundancy_enabled = true

  anonymous_pull_enabled = false
  data_endpoint_enabled  = true

  retention_policy {
    days    = var.retention_days
    enabled = var.retention_enabled
  }

  trust_policy {
    enabled = var.content_trust_enabled
  }

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
