resource "azurerm_private_dns_zone" "zones" {
  for_each = toset(var.private_dns_zones)

  name                = each.value
  resource_group_name = var.resource_group_name

  tags = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "links" {
  for_each = azurerm_private_dns_zone.zones

  name                  = "${replace(each.key, ".", "-")}-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = each.value.name
  virtual_network_id    = var.virtual_network_id

  registration_enabled = false
}
