variable "location" {
  type    = string
  default = "East US"
}

variable "resource_group_name" {
  type    = string
  default = "rg-k3s-production"
}

variable "virtual_network_id" {
  type = string
}

module "private_dns" {
  source = "../../modules/private-dns"

  name_prefix          = "k3s-production"
  resource_group_name = var.resource_group_name
  virtual_network_id  = var.virtual_network_id

  zones = [
    "privatelink.azurecr.io",
    "privatelink.vaultcore.azure.net",
    "privatelink.redis.cache.windows.net",
    "privatelink.postgres.database.azure.com"
  ]
}

module "load_balancer" {
  source = "../../modules/load-balancer"

  name                = "k3s-production-lb"
  location            = var.location
  resource_group_name = var.resource_group_name
}

module "managed_redis" {
  source = "../../modules/managed-redis"

  name                = "k3s-production-redis"
  location            = var.location
  resource_group_name = var.resource_group_name
}
