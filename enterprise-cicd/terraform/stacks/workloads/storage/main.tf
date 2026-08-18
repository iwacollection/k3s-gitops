module "resource_group" {
  source = "../../../modules/resource-group"

  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

module "storage" {
  source = "../../../modules/storage-account"

  name                          = var.storage_account_name
  resource_group_name           = module.resource_group.name
  location                      = module.resource_group.location
  replication_type              = var.replication_type
  access_tier                   = var.access_tier
  public_network_access_enabled = var.public_network_access_enabled
  shared_key_access_enabled     = false
  blob_versioning_enabled       = var.blob_versioning_enabled
  delete_retention_days         = var.delete_retention_days
  tags                          = var.tags
}
