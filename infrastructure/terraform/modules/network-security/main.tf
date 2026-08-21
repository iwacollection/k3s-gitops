terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

resource "azurerm_network_security_group" "main" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = {
    managed_by = "terraform"
  }

  lifecycle {
    prevent_destroy = true
  }
}
