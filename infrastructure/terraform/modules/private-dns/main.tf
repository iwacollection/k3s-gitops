resource "azurerm_private_dns_zone" "private" {
  for_each = toset(var.private_dns_zones)

  name                = each.value
  resource_group_name = var.resource_group_name

  tags = {
    managed_by = "terraform"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "link" {
  for_each = azurerm_private_dns_zone.private

  name                  = "${var.name}-${replace(each.key, ".", "-")}-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = each.value.name
  virtual_network_id    = var.virtual_network_id

  registration_enabled = false
}
