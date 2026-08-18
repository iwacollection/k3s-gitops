variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "key_vault_name" { type = string }
variable "sku_name" { type = string }
variable "purge_protection_enabled" { type = bool }
variable "soft_delete_retention_days" { type = number }
variable "public_network_access_enabled" { type = bool }
variable "tags" {
  type    = map(string)
  default = {}
}
