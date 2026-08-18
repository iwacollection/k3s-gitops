module "resource_group" {
  source = "../../../modules/resource-group"
  name = var.resource_group_name
  location = var.location
  tags = var.tags
}

module "managed_identity" {
  source = "../../../modules/managed-identity"
  name = var.identity_name
  resource_group_name = module.resource_group.name
  location = module.resource_group.location
  federated_credentials = {}
  tags = var.tags
}
