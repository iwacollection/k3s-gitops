module "resource_group" {
  source = "../../../modules/resource-group"

  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

module "load_balancer" {
  source = "../../../modules/load-balancer"

  name                        = var.load_balancer_name
  resource_group_name         = module.resource_group.name
  location                    = module.resource_group.location
  exposure                    = var.exposure
  subnet_id                   = var.subnet_id
  frontend_private_ip_address = var.frontend_private_ip_address
  frontend_port               = var.frontend_port
  backend_port                = var.backend_port
  protocol                    = var.protocol
  probe_protocol              = var.probe_protocol
  probe_port                  = var.probe_port
  probe_request_path          = var.probe_request_path
  idle_timeout_in_minutes     = var.idle_timeout_in_minutes
  tags                        = var.tags
}
