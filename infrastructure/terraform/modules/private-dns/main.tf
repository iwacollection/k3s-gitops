variable "name_prefix" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "virtual_network_id" {
  type = string
}

variable "zones" {
  type = set(string)
}

resource "azurerm_private_dns_zone" "this" {
  for_each            = var.zones
  name                = each.value
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each              = azurerm_private_dns_zone.this
  name                  = "${var.name_prefix}-${replace(each.key, ".", "-")}-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = each.value.name
  virtual_network_id    = var.virtual_network_id
  registration_enabled  = false
}

output "zone_ids" {
  value = { for k, v in azurerm_private_dns_zone.this : k => v.id }
}
