terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

resource "azurerm_private_endpoint" "main" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "${var.name}-connection"
    private_connection_resource_id = var.resource_id
    is_manual_connection           = false
  }

  dynamic "private_dns_zone_group" {
    for_each = length(var.private_dns_zone_ids) > 0 ? [1] : []

    content {
      name = "default"

      private_dns_zone_ids = var.private_dns_zone_ids
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}
