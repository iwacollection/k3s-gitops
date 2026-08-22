data "azurerm_client_config" "current" {}

locals {
  unique_suffix  = substr(replace(data.azurerm_client_config.current.subscription_id, "-", ""), 0, 8)
  acr_name       = "k3sprodacr${local.unique_suffix}"
  key_vault_name = "k3s-prod-kv-${local.unique_suffix}"
}

module "network" {
  source = "../../modules/network"

  name                = "k3s-production-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
}

module "network_security" {
  source = "../../modules/network-security"

  name                = "k3s-production-aks-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = module.network.aks_subnet_id
  network_security_group_id = module.network_security.id
}

module "nat_gateway" {
  source = "../../modules/nat-gateway"

  name                = "k3s-production-nat"
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_subnet_nat_gateway_association" "aks" {
  subnet_id      = module.network.aks_subnet_id
  nat_gateway_id = module.nat_gateway.id
}

module "monitoring" {
  source = "../../modules/monitoring"

  name                = "k3s-production-law"
  location            = var.location
  resource_group_name = var.resource_group_name
}

module "container_registry" {
  source = "../../modules/container-registry"

  name                = local.acr_name
  location            = var.location
  resource_group_name = var.resource_group_name
}

module "key_vault" {
  source = "../../modules/key-vault"

  name                       = local.key_vault_name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days = 7
}

module "aks" {
  source = "../../modules/aks"

  name                       = "k3s-production-aks"
  dns_prefix                 = "k3s-production"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  subnet_id                  = module.network.aks_subnet_id
  log_analytics_workspace_id = module.monitoring.id

  depends_on = [
    azurerm_subnet_network_security_group_association.aks,
    azurerm_subnet_nat_gateway_association.aks,
  ]
}
