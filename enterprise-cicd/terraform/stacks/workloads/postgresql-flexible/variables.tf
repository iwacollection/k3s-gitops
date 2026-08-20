variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "postgresql_server_name" { type = string }
variable "postgresql_version" { type = string }
variable "sku_name" { type = string }
variable "storage_mb" { type = number }
variable "storage_tier" { type = string }
variable "backup_retention_days" { type = number }
variable "geo_redundant_backup_enabled" { type = bool }
variable "auto_grow_enabled" { type = bool }
variable "high_availability_mode" {
  type    = string
  default = null
}
variable "network_resource_group_name" { type = string }
variable "virtual_network_name" { type = string }
variable "delegated_subnet_name" { type = string }
variable "private_dns_zone_name" { type = string }
variable "entra_admin_object_id" {
  type    = string
  default = null
}
variable "entra_admin_principal_name" {
  type    = string
  default = null
}
variable "entra_admin_principal_type" {
  type    = string
  default = "Group"
}
variable "lock_enabled" {
  type    = bool
  default = false
}
variable "tags" {
  type    = map(string)
  default = {}
}
