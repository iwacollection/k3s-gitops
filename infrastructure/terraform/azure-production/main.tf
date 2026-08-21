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
  name = var.name
  resource_group_name = azurerm_resource_group.production.name
  location = azurerm_resource_group.production.location
  address_space = var.address_space
}

module "network_security" {
  source = "../modules/network-security"
  name = "${var.name}-nsg"
  resource_group_name = azurerm_resource_group.production.name
  location = azurerm_resource_group.production.location
}

module "nat_gateway" {
  source = "../modules/nat-gateway"
  name = "${var.name}-nat"
  resource_group_name = azurerm_resource_group.production.name
  location = azurerm_resource_group.production.location
}

module "subnet_association" {
  source = "../modules/subnet-association"
  subnet_id = module.network.subnet_id
  nat_gateway_id = module.nat_gateway.id
  network_security_group_id = module.network_security.id
}

module "load_balancer" {
  source = "../modules/load-balancer"
  name = "${var.name}-lb"
  resource_group_name = azurerm_resource_group.production.name
  location = azurerm_resource_group.production.location
  subnet_id = module.network.subnet_id
}

module "database" {
  source = "../modules/database"
  name = "${var.name}-db"
  resource_group_name = azurerm_resource_group.production.name
  location = azurerm_resource_group.production.location
}

module "aks" {
  source = "../modules/aks"
  name = "${var.name}-aks"
  resource_group_name = azurerm_resource_group.production.name
  location = azurerm_resource_group.production.location
  private_cluster_enabled = true
  azure_rbac_enabled = true
  workload_identity_enabled = true
  oidc_issuer_enabled = true
}

module "container_registry" {
  source = "../modules/container_registry"
  name = "${var.name}acr"
  resource_group_name = azurerm_resource_group.production.name
  location = azurerm_resource_group.production.location
}

module "keyvault" {
  source = "../modules/keyvault"
  name = "${var.name}-kv"
  resource_group_name = azurerm_resource_group.production.name
  location = azurerm_resource_group.production.location
}

module "monitoring" {
  source = "../modules/monitoring"
  name = "${var.name}-monitoring"
  resource_group_name = azurerm_resource_group.production.name
  location = azurerm_resource_group.production.location
}

module "private_dns" {
  source = "../modules/private-dns"
  name = "${var.name}-private-dns"
  resource_group_name = azurerm_resource_group.production.name
  location = azurerm_resource_group.production.location
  virtual_network_id = module.network.vnet_id
}

module "postgres_private_endpoint" {
  source = "../modules/private-endpoint"
  name = "${var.name}-postgres-pe"
  location = azurerm_resource_group.production.location
  resource_group_name = azurerm_resource_group.production.name
  subnet_id = module.network.private_endpoint_subnet_id
  resource_id = module.database.id
}

module "acr_private_endpoint" {
  source = "../modules/private-endpoint"
  name = "${var.name}-acr-pe"
  location = azurerm_resource_group.production.location
  resource_group_name = azurerm_resource_group.production.name
  subnet_id = module.network.private_endpoint_subnet_id
  resource_id = module.container_registry.id
}

module "keyvault_private_endpoint" {
  source = "../modules/private-endpoint"
  name = "${var.name}-kv-pe"
  location = azurerm_resource_group.production.location
  resource_group_name = azurerm_resource_group.production.name
  subnet_id = module.network.private_endpoint_subnet_id
  resource_id = module.keyvault.id
}

module "rbac" {
  source = "../modules/rbac"
  name = "${var.name}-rbac"
  resource_group_name = azurerm_resource_group.production.name
  aks_identity_id = module.aks.identity_id
  acr_id = module.container_registry.id
  keyvault_id = module.keyvault.id
}
