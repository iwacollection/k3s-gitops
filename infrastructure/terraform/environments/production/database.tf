module "database" {
  source = "../../modules/database"

  name                = "k3s-production-postgres"
  location            = var.database_location
  resource_group_name = var.resource_group_name
  sku_name            = var.database_sku_name

  admin_username = var.database_admin_username
  admin_password = var.database_admin_password

  private_endpoint_enabled    = var.database_private_endpoint_enabled
  private_endpoint_subnet_id  = var.database_private_endpoint_subnet_id
  private_dns_zone_ids        = var.database_private_dns_zone_ids
}
