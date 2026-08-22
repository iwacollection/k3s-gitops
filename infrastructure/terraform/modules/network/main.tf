resource "azurerm_virtual_network" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.address_space
}

resource "azurerm_subnet" "aks" {
  name                 = "${var.name}-aks"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = var.aks_subnet_prefixes

  service_endpoints = [
    "Microsoft.KeyVault",
    "Microsoft.Storage",
  ]
}

resource "azurerm_subnet" "private_endpoints" {
  name                              = "${var.name}-private-endpoints"
  resource_group_name               = var.resource_group_name
  virtual_network_name              = azurerm_virtual_network.this.name
  address_prefixes                  = var.private_endpoint_subnet_prefixes
  private_endpoint_network_policies = "Disabled"
}

resource "azurerm_subnet" "ingress" {
  name                 = "${var.name}-ingress"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = var.ingress_subnet_prefixes
}
