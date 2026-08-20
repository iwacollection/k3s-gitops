variable "name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "subnet_id" { type = string }
variable "private_connection_resource_id" { type = string }

variable "subresource_names" {
  type    = list(string)
  default = []
}

variable "private_dns_zone_ids" {
  type    = list(string)
  default = []
}

variable "is_manual_connection" {
  type    = bool
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
