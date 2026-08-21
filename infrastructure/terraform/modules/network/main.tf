terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

resource "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.address_space

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_subnet" "main" {
  name                 = var.subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.subnet_prefixes

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_subnet" "private_endpoint" {
  name                 = "${var.subnet_name}-private-endpoint"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.private_endpoint_subnet_prefixes

  private_endpoint_network_policies = "Disabled"

  lifecycle {
    prevent_destroy = true
  }
}
