variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "address_space" {
  type = list(string)
}

variable "dns_servers" {
  type    = list(string)
  default = []
}

variable "subnets" {
  type = map(object({
    address_prefixes          = list(string)
    service_endpoints         = optional(list(string), [])
    network_security_group_id = optional(string)
    route_table_id            = optional(string)
    nat_gateway_id            = optional(string)
    delegation = optional(object({
      name         = string
      service_name = string
      actions      = optional(list(string), [])
    }))
  }))
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}
