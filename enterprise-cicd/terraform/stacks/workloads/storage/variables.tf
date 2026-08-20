variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "storage_account_name" { type = string }
variable "replication_type" { type = string }
variable "access_tier" { type = string }
variable "public_network_access_enabled" { type = bool }
variable "blob_versioning_enabled" { type = bool }
variable "delete_retention_days" { type = number }
variable "network_resource_group_name" {
  type    = string
  default = null
}
variable "virtual_network_name" {
  type    = string
  default = null
}
variable "private_endpoint_subnet_name" {
  type    = string
  default = "snet-private-endpoints"
}
variable "private_dns_zone_name" {
  type    = string
  default = "privatelink.blob.core.windows.net"
}
variable "tags" {
  type    = map(string)
  default = {}
}
