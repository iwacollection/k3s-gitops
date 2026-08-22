variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "sku" {
  type    = string
  default = "Premium"
}

variable "public_network_access_enabled" {
  type    = bool
  default = false
}

variable "geo_replication_locations" {
  type    = list(string)
  default = []
}
