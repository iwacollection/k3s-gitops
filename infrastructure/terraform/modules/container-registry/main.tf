resource "azurerm_container_registry" "this" {
  name                          = var.name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = "Premium"
  admin_enabled                 = false
  public_network_access_enabled = var.public_network_access_enabled

  content_trust_enabled = true

  retention_policy {
    days    = 30
    enabled = true
  }

  georeplications {
    location = var.location
  }

  zone_redundancy_enabled = true
  data_endpoint_enabled   = true
  anonymous_pull_enabled  = false
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
