terraform {
  required_version = ">= 1.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "platform" {
  name     = "rg-iac-dev-platform"
  location = "East Asia"
}

module "network" {
  source = "../../modules/network"

  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location

  vnet_name   = "vnet-iac-dev"
  subnet_name = "subnet-platform"

  address_space = [
    "10.10.0.0/16"
  ]

  subnet_prefixes = [
    "10.10.1.0/24"
  ]
}
