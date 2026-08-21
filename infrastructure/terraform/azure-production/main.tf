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

resource "azurerm_resource_group" "production" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    environment = "production"
    managed_by  = "terraform"
  }

  lifecycle {
    prevent_destroy = true
  }
}

module "network" {
  source = "../modules/network"

  name                = var.name
  resource_group_name = azurerm_resource_group.production.name
  location            = azurerm_resource_group.production.location
  address_space       = var.address_space
}

module "load_balancer" {
  source = "../modules/load-balancer"

  name                = "${var.name}-lb"
  resource_group_name = azurerm_resource_group.production.name
  location            = azurerm_resource_group.production.location
  subnet_id           = module.network.subnet_id
}

module "database" {
  source = "../modules/database"

  name                = "${var.name}-db"
  resource_group_name = azurerm_resource_group.production.name
  location            = azurerm_resource_group.production.location
}

module "aks" {
  source = "../modules/aks"

  name                = "${var.name}-aks"
  resource_group_name = azurerm_resource_group.production.name
  location            = azurerm_resource_group.production.location

  private_cluster_enabled      = true
  azure_rbac_enabled           = true
  workload_identity_enabled    = true
  oidc_issuer_enabled          = true
}

module "container_registry" {
  source = "../modules/container_registry"

  name                = "${var.name}acr"
  resource_group_name = azurerm_resource_group.production.name
  location            = azurerm_resource_group.production.location
}

module "keyvault" {
  source = "../modules/keyvault"

  name                = "${var.name}-kv"
  resource_group_name = azurerm_resource_group.production.name
  location            = azurerm_resource_group.production.location
}

module "monitoring" {
  source = "../modules/monitoring"

  name                = "${var.name}-monitoring"
  resource_group_name = azurerm_resource_group.production.name
  location            = azurerm_resource_group.production.location
}
