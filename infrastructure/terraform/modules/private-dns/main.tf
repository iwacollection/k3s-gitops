variable "resource_group_name" {
  type = string
}

variable "virtual_network_id" {
  type = string
}

variable "zones" {
  description = "Map of private DNS zone name to VNet link name. Explicit link names preserve existing resources during module adoption."
  type        = map(string)
}

resource "azurerm_private_dns_zone" "this" {
  for_each            = var.zones
  name                = each.key
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each              = var.zones
  name                  = each.value
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.this[each.key].name
  virtual_network_id    = var.virtual_network_id
  registration_enabled  = false
}

output "zone_ids" {
  value = { for k, v in azurerm_private_dns_zone.this : k => v.id }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.this]
}
