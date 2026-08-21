resource "azurerm_management_lock" "vnet" {
  name       = "${var.vnet_name}-production-protection"
  scope      = azurerm_virtual_network.main.id
  lock_level = "CanNotDelete"
  notes      = "Protect production virtual network from accidental deletion"
}

resource "azurerm_management_lock" "subnet" {
  name       = "${var.subnet_name}-production-protection"
  scope      = azurerm_subnet.main.id
  lock_level = "CanNotDelete"
  notes      = "Protect production subnet from accidental deletion"
}
