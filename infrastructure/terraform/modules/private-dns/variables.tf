variable "name" {
  type = string
}

variable "private_dns_zones" {
  type = list(string)
}

variable "resource_group_name" {
  type = string
}

variable "virtual_network_id" {
  type = string
}
