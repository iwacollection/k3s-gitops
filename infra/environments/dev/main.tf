resource "azurerm_resource_group" "platform" {
  name     = "rg-iac-dev-platform"
  location = "eastus"
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-iac-dev"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  address_space       = ["10.20.0.0/16"]
}

resource "azurerm_subnet" "main" {
  name                 = "subnet-platform"
  resource_group_name  = azurerm_resource_group.platform.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.20.1.0/24"]
}
