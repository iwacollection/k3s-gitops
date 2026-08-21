module "database" {
  source = "../../modules/database"

  name                = "k3s-production-postgres"
  location            = var.location
  resource_group_name = var.resource_group_name

  admin_username = var.database_admin_username
  admin_password = var.database_admin_password
}
