terraform {
  required_version = ">= 1.6.0"

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

module "network" {
  source = "../modules/network"

  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = var.address_space
}

module "load_balancer" {
  source = "../modules/load-balancer"

  name                = "${var.name}-lb"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = module.network.subnet_id
}

module "database" {
  source = "../modules/database"

  name                = "${var.name}-db"
  resource_group_name = var.resource_group_name
  location            = var.location
}
