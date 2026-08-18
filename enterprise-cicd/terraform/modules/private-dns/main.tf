resource "azurerm_private_dns_zone" "this" {
  for_each = var.zones

  name                = each.key
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

locals {
  virtual_network_links = merge([
    for zone_name, zone in var.zones : {
      for link_name, virtual_network_id in zone.virtual_network_links :
      "${zone_name}/${link_name}" => {
        zone_name          = zone_name
        link_name          = link_name
        virtual_network_id = virtual_network_id
      }
    }
  ]...)
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each = local.virtual_network_links

  name                  = each.value.link_name
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.this[each.value.zone_name].name
  virtual_network_id    = each.value.virtual_network_id
  registration_enabled  = false
  tags                  = var.tags
}
