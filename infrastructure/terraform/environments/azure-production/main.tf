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
  source = "../../modules/network"

  name     = var.name
  location = var.location
}

module "identity" {
  source = "../../modules/identity"

  name     = var.name
  location = var.location
}

module "container_registry" {
  source = "../../modules/container_registry"

  name     = var.name
  location = var.location
}

module "keyvault" {
  source = "../../modules/keyvault"

  name     = var.name
  location = var.location
}

module "monitoring" {
  source = "../../modules/monitoring"

  name     = var.name
  location = var.location
}

module "database" {
  source = "../../modules/database"

  name     = var.name
  location = var.location
}

module "load_balancer" {
  source = "../../modules/load_balancer"

  name     = var.name
  location = var.location
}
