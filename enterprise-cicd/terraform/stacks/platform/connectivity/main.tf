module "resource_group" {
  source = "../../../modules/resource-group"

  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

module "network_security_group" {
  for_each = var.network_security_groups
  source   = "../../../modules/network-security-group"

  name                = each.value.name
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  rules               = each.value.rules
  tags                = var.tags
}

module "route_table" {
  for_each = var.route_tables
  source   = "../../../modules/route-table"

  name                = each.value.name
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  routes              = each.value.routes
  tags                = var.tags
}

module "nat_gateway" {
  for_each = var.nat_gateway == null ? {} : { default = var.nat_gateway }
  source   = "../../../modules/nat-gateway"

  name                    = each.value.name
  public_ip_name          = each.value.public_ip_name
  resource_group_name     = module.resource_group.name
  location                = module.resource_group.location
  idle_timeout_in_minutes = each.value.idle_timeout_in_minutes
  zones                   = each.value.zones
  tags                    = var.tags
}

module "network" {
  source = "../../../modules/network"

  name                = var.virtual_network_name
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  address_space       = var.address_space
  tags                = var.tags

  subnets = {
    for key, subnet in var.subnets : key => {
      address_prefixes          = subnet.address_prefixes
      service_endpoints         = subnet.service_endpoints
      delegation                = subnet.delegation
      network_security_group_id = subnet.nsg_key == null ? null : module.network_security_group[subnet.nsg_key].id
      route_table_id            = subnet.route_table_key == null ? null : module.route_table[subnet.route_table_key].id
      nat_gateway_id            = subnet.use_nat_gateway && var.nat_gateway != null ? module.nat_gateway["default"].id : null
    }
  }
}

module "private_dns" {
  source = "../../../modules/private-dns"

  resource_group_name = module.resource_group.name
  tags                = var.tags
  zones = {
    for zone_name in var.private_dns_zone_names : zone_name => {
      virtual_network_links = {
        primary = module.network.id
      }
    }
  }
}
