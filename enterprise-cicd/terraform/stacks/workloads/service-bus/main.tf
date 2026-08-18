module "resource_group" {
  source = "../../../modules/resource-group"

  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

module "service_bus" {
  source = "../../../modules/service-bus"

  name                          = var.service_bus_name
  resource_group_name           = module.resource_group.name
  location                      = module.resource_group.location
  sku                           = var.sku
  capacity                      = var.capacity
  public_network_access_enabled = var.public_network_access_enabled
  tags                          = var.tags
}
