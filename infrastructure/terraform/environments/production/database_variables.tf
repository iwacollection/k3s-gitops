variable "database_admin_username" {
  type      = string
  sensitive = true
}

variable "database_admin_password" {
  type      = string
  sensitive = true
}

variable "database_location" {
  type    = string
  default = "East US 2"
}

variable "database_sku_name" {
  type    = string
  default = "GP_Standard_D2s_v3"
}

variable "database_private_endpoint_enabled" {
  type    = bool
  default = true
}

variable "database_private_endpoint_subnet_id" {
  type    = string
  default = null
}

variable "database_private_dns_zone_ids" {
  type    = list(string)
  default = []
}
