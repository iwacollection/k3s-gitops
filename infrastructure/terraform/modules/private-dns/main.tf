resource "azurerm_private_dns_zone" "private" {
  name                = var.zone_name
  resource_group_name = var.resource_group_name

  tags = {
    managed_by = "terraform"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "link" {
  name                  = "${var.name}-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.private.name
  virtual_network_id    = var.virtual_network_id

  registration_enabled = false
}
