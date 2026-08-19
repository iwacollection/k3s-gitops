variable "name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "gateway_subnet_id" { type = string }
variable "public_ip_name" { type = string }
variable "sku" {
  type    = string
  default = "VpnGw1"
}
variable "bgp_enabled" {
  type    = bool
  default = false
}
variable "active_active" {
  type    = bool
  default = false
}
variable "tags" {
  type    = map(string)
  default = {}
}
