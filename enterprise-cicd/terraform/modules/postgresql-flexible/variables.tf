variable "name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "version" { type = string }
variable "sku_name" { type = string }
variable "storage_mb" { type = number }
variable "storage_tier" { type = string }
variable "delegated_subnet_id" { type = string }
variable "private_dns_zone_id" { type = string }
variable "backup_retention_days" { type = number }
variable "geo_redundant_backup_enabled" { type = bool }
variable "auto_grow_enabled" { type = bool }
variable "high_availability_mode" {
  type    = string
  default = null
}
variable "zone" {
  type    = string
  default = null
}
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
variable "tags" {
  type    = map(string)
  default = {}
}
