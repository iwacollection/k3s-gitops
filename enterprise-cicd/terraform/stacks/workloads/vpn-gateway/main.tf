module "resource_group" {
  source = "../../../modules/resource-group"

  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

module "network" {
  source = "../../../modules/network"

  name                = var.virtual_network_name
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  address_space       = var.address_space
  subnets = {
    GatewaySubnet = {
      address_prefixes  = [var.gateway_subnet_prefix]
      service_endpoints = []
    }
  }
  tags = var.tags
}

module "vpn_gateway" {
  source = "../../../modules/vpn-gateway"

  name                = var.gateway_name
  public_ip_name      = var.public_ip_name
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  gateway_subnet_id   = module.network.subnet_ids["GatewaySubnet"]
  sku                 = var.sku
  bgp_enabled         = var.bgp_enabled
  active_active       = var.active_active
  tags                = var.tags
}
