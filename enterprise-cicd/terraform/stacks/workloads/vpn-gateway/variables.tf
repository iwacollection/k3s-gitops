variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "virtual_network_name" {
  type = string
}

variable "address_space" {
  type = list(string)
}

variable "gateway_subnet_prefix" {
  type = string
}

variable "gateway_name" {
  type = string
}

variable "public_ip_name" {
  type = string
}

variable "sku" {
  type = string
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
