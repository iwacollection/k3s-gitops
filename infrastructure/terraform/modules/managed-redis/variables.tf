variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "sku_name" {
  type    = string
  default = "Premium"
}

variable "capacity" {
  type    = number
  default = 1
}

variable "public_network_access_enabled" {
  type    = bool
  default = false
}
