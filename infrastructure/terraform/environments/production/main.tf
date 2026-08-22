variable "location" {
  type    = string
  default = "East US"
}

variable "resource_group_name" {
  type    = string
  default = "rg-k3s-production"
}

module "private_dns" {
  source = "../../modules/private-dns"

  resource_group_name = var.resource_group_name
  virtual_network_id  = module.network.vnet_id

  zones = {
    "privatelink.azurecr.io"                  = "k3s-production-acr-pe-dns-link"
    "privatelink.vaultcore.azure.net"         = "k3s-production-kv-pe-dns-link"
    "privatelink.redis.cache.windows.net"     = "k3s-production-redis-pe-dns-link"
    "privatelink.postgres.database.azure.com" = "k3s-production-postgres-pe-dns-link"
  }
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

module "application_gateway_waf" {
  source = "../../modules/application-gateway-waf"

  name                = "k3s-production-appgw-waf"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = module.network.ingress_subnet_id
}
