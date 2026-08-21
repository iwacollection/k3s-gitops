variable "location" {
  type    = string
  default = "East US"
}

variable "resource_group_name" {
  type    = string
  default = "rg-k3s-production"
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
