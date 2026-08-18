variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "service_bus_name" { type = string }
variable "sku" { type = string }
variable "capacity" { type = number }
variable "public_network_access_enabled" { type = bool }
variable "tags" {
  type    = map(string)
  default = {}
}
