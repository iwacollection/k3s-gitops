variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "virtual_network_name" { type = string }
variable "address_space" { type = list(string) }

variable "network_security_groups" {
  type = map(object({
    name = string
    rules = map(object({
      priority                   = number
      direction                  = string
      access                     = string
      protocol                   = string
      source_port_range          = string
      destination_port_range     = string
      source_address_prefix      = string
      destination_address_prefix = string
    }))
  }))
  default = {}
}

variable "route_tables" {
  type = map(object({
    name = string
    routes = map(object({
      address_prefix         = string
      next_hop_type          = string
      next_hop_in_ip_address = optional(string)
    }))
  }))
  default = {}
}

variable "nat_gateway" {
  type = object({
    name                    = string
    public_ip_name          = string
    idle_timeout_in_minutes = optional(number, 4)
    zones                   = optional(list(string), [])
  })
  default  = null
  nullable = true
}

variable "subnets" {
  type = map(object({
    address_prefixes  = list(string)
    service_endpoints = optional(list(string), [])
    nsg_key           = optional(string)
    route_table_key   = optional(string)
    use_nat_gateway   = optional(bool, false)
    delegation = optional(object({
      name         = string
      service_name = string
      actions      = optional(list(string), [])
    }))
  }))
  default = {}
}

variable "private_dns_zone_names" {
  type    = set(string)
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
