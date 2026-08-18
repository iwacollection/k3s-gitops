variable "resource_group_name" { type = string }

variable "zones" {
  type = map(object({
    virtual_network_links = map(string)
  }))
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}
