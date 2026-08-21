terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

resource "azurerm_subnet_nat_gateway_association" "this" {
  subnet_id      = var.subnet_id
  nat_gateway_id = var.nat_gateway_id
}

resource "azurerm_subnet_network_security_group_association" "this" {
  subnet_id                 = var.subnet_id
  network_security_group_id = var.network_security_group_id
}
