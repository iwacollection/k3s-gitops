variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "resource_id" {
  type = string
}

variable "private_dns_zone_ids" {
  description = "Private DNS zones associated with this endpoint"
  type        = list(string)
  default     = []
}
