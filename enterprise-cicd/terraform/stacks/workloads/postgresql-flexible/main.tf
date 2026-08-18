locals {
  environment             = lookup(var.tags, "environment", "dev")
  bindings                = jsondecode(file("${path.root}/../../../../contracts/environment-bindings.json"))
  postgresql_dba_binding  = local.bindings.environments[local.environment].identities.postgresqlDba
  prod_dba_binding_ready  = local.environment != "prod" || (try(local.postgresql_dba_binding.objectId, null) != null && try(local.postgresql_dba_binding.principalName, null) != null)
}

resource "terraform_data" "governance" {
  input = local.environment

  lifecycle {
    precondition {
      condition     = local.prod_dba_binding_ready
      error_message = "PROD PostgreSQL is blocked until environments.prod.identities.postgresqlDba.objectId and principalName are configured in environment-bindings.json."
    }
  }
}

data "azurerm_subnet" "postgres" {
  name                 = var.delegated_subnet_name
  virtual_network_name = var.virtual_network_name
  resource_group_name  = var.network_resource_group_name
}

data "azurerm_private_dns_zone" "postgres" {
  name                = var.private_dns_zone_name
  resource_group_name = var.network_resource_group_name
}

module "resource_group" {
  source = "../../../modules/resource-group"

  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

module "postgresql" {
  source = "../../../modules/postgresql-flexible"

  name                         = var.postgresql_server_name
  resource_group_name          = module.resource_group.name
  location                     = module.resource_group.location
  postgresql_version           = var.postgresql_version
  sku_name                     = var.sku_name
  storage_mb                   = var.storage_mb
  storage_tier                 = var.storage_tier
  delegated_subnet_id          = data.azurerm_subnet.postgres.id
  private_dns_zone_id          = data.azurerm_private_dns_zone.postgres.id
  backup_retention_days        = var.backup_retention_days
  geo_redundant_backup_enabled = var.geo_redundant_backup_enabled
  auto_grow_enabled            = var.auto_grow_enabled
  high_availability_mode       = var.high_availability_mode
  entra_admin_object_id        = try(local.postgresql_dba_binding.objectId, null)
  entra_admin_principal_name   = try(local.postgresql_dba_binding.principalName, null)
  entra_admin_principal_type   = try(local.postgresql_dba_binding.principalType, "Group")
  tags                         = var.tags

  depends_on = [terraform_data.governance]
}

module "resource_lock" {
  count  = lookup(var.tags, "environment", "") == "prod" ? 1 : 0
  source = "../../../modules/resource-lock"

  name       = "lock-${var.postgresql_server_name}"
  scope      = module.postgresql.id
  lock_level = "CanNotDelete"
  notes      = "Production PostgreSQL Flexible Server protected by enterprise IaC policy."
}
