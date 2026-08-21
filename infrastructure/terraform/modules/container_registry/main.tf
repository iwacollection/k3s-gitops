terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

resource "azurerm_container_registry" "main" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku

  admin_enabled = false

  public_network_access_enabled = false

  retention_policy {
    enabled = true
    days    = 7
  }

  lifecycle {
    prevent_destroy = true
  }
}
