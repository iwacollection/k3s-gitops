variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "admin_username" {
  type      = string
  sensitive = true
}

variable "admin_password" {
  type      = string
  sensitive = true
}

variable "postgres_version" {
  type    = string
  default = "16"
}

variable "sku_name" {
  type    = string
  default = "GP_Standard_D2s_v3"
}

variable "zone" {
  type        = string
  description = "Availability zone for the PostgreSQL Flexible Server. Keep aligned with the existing managed server to avoid an invalid zone migration."
  default     = "1"
}

variable "storage_mb" {
  type    = number
  default = 32768
}

variable "backup_retention_days" {
  type    = number
  default = 35
}

variable "public_network_access_enabled" {
  type    = bool
  default = false
}

variable "private_endpoint_enabled" {
  type    = bool
  default = true
}

variable "private_endpoint_subnet_id" {
  type    = string
  default = null

  validation {
    condition     = var.private_endpoint_enabled == false || var.private_endpoint_subnet_id != null
    error_message = "private_endpoint_subnet_id must be provided when PostgreSQL private endpoint is enabled."
  }
}

variable "private_dns_zone_ids" {
  type    = list(string)
  default = []

  validation {
    condition     = var.private_endpoint_enabled == false || length(var.private_dns_zone_ids) > 0
    error_message = "private_dns_zone_ids must be provided when PostgreSQL private endpoint is enabled."
  }
}
