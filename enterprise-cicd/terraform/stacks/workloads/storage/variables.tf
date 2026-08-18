variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "storage_account_name" { type = string }
variable "replication_type" { type = string }
variable "access_tier" { type = string }
variable "public_network_access_enabled" { type = bool }
variable "blob_versioning_enabled" { type = bool }
variable "delete_retention_days" { type = number }
variable "tags" {
  type    = map(string)
  default = {}
}
