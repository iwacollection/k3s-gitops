resource "azurerm_resource_group" "platform" {
  name     = "rg-iac-dev-platform"
  location = "eastus"
}

module "network" {
  source = "../../modules/network"

  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location

  vnet_name      = "vnet-iac-dev"
  address_space  = ["10.20.0.0/16"]

  subnet_name     = "subnet-platform"
  subnet_prefixes = ["10.20.1.0/24"]
}
