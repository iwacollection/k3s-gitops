module "resource_group" {
  source = "../../../modules/resource-group"

  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

module "identities" {
  for_each = var.identity_specs
  source   = "../../../modules/managed-identity"

  name                  = each.value.name
  location              = module.resource_group.location
  resource_group_name   = module.resource_group.name
  tags                  = merge(var.tags, { identity_contract = each.key })
  federated_credentials = each.value.federated_credentials
}
