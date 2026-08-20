variable "name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }

variable "routes" {
  type = map(object({
    address_prefix         = string
    next_hop_type          = string
    next_hop_in_ip_address = optional(string)
  }))
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}
