variable "name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "sku_name" { type = string }
variable "high_availability_enabled" { type = bool }
variable "public_network_access" { type = string }
variable "clustering_policy" { type = string }
variable "eviction_policy" { type = string }
variable "persistence_redis_database_backup_frequency" {
  type    = string
  default = null
}
variable "tags" {
  type    = map(string)
  default = {}
}
