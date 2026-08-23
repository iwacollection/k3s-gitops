variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "soft_delete_retention_days" {
  type    = number
  default = 90
}

variable "purge_protection_enabled" {
  type    = bool
  default = true
}

variable "public_network_access_enabled" {
  type    = bool
  default = false
}

variable "network_acls_default_action" {
  type    = string
  default = "Deny"
}

variable "network_acls_bypass" {
  type    = string
  default = "AzureServices"
}

variable "allowed_ip_ranges" {
  type    = list(string)
  default = []
}

variable "allowed_subnet_ids" {
  type    = list(string)
  default = []
}

variable "private_endpoint_enabled" {
  type    = bool
  default = true
}

variable "private_endpoint_subnet_id" {
  type    = string
  default = null
}

variable "private_dns_zone_ids" {
  type    = list(string)
  default = []
}
