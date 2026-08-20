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
  default = "AZFW_VNet"
}

variable "sku_tier" {
  type    = string
  default = "Standard"
}

variable "firewall_policy_id" {
  type    = string
  default = null
}
