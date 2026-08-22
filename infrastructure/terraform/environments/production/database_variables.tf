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
