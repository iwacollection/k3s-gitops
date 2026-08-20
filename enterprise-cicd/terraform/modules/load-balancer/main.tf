resource "azurerm_public_ip" "this" {
  count = var.exposure == "public" ? 1 : 0

  name                = "${var.name}-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_lb" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Standard"
  tags                = var.tags

  frontend_ip_configuration {
    name                          = "frontend"
    public_ip_address_id          = var.exposure == "public" ? azurerm_public_ip.this[0].id : null
    subnet_id                     = var.exposure == "internal" ? var.subnet_id : null
    private_ip_address            = var.exposure == "internal" ? var.frontend_private_ip_address : null
    private_ip_address_allocation = var.exposure == "internal" && var.frontend_private_ip_address != null ? "Static" : var.exposure == "internal" ? "Dynamic" : null
  }

  lifecycle {
    precondition {
      condition     = var.exposure != "internal" || var.subnet_id != null
      error_message = "Internal load balancers require subnet_id."
    }
  }
}

resource "azurerm_lb_backend_address_pool" "this" {
  name            = "backend"
  loadbalancer_id = azurerm_lb.this.id
}

resource "azurerm_lb_probe" "this" {
  name                = "health"
  loadbalancer_id     = azurerm_lb.this.id
  protocol            = var.probe_protocol
  port                = var.probe_port
  request_path        = contains(["Http", "Https"], var.probe_protocol) ? var.probe_request_path : null
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "this" {
  name                           = "primary"
  loadbalancer_id                = azurerm_lb.this.id
  protocol                       = var.protocol
  frontend_port                  = var.frontend_port
  backend_port                   = var.backend_port
  frontend_ip_configuration_name = "frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.this.id]
  probe_id                       = azurerm_lb_probe.this.id
  idle_timeout_in_minutes        = var.idle_timeout_in_minutes
  floating_ip_enabled            = false
  tcp_reset_enabled              = var.protocol == "Tcp"
}
