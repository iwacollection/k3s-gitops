module "resource_group" {
  source = "../../../modules/resource-group"

  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

module "acr" {
  source = "../../../modules/acr"

  name                          = var.acr_name
  resource_group_name           = module.resource_group.name
  location                      = module.resource_group.location
  sku                           = var.sku
  public_network_access_enabled = var.public_network_access_enabled
  retention_days                = var.retention_days
  tags                          = var.tags
}
