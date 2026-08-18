variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "sku_name" {
  type    = string
  default = "standard"
  validation {
    condition     = contains(["standard", "premium"], lower(var.sku_name))
    error_message = "sku_name must be standard or premium."
  }
}

variable "purge_protection_enabled" {
  type    = bool
  default = true
}

variable "soft_delete_retention_days" {
  type    = number
  default = 90
  validation {
    condition     = var.soft_delete_retention_days >= 7 && var.soft_delete_retention_days <= 90
    error_message = "soft_delete_retention_days must be between 7 and 90."
  }
}

variable "public_network_access_enabled" {
  type = bool
}

variable "tags" {
  type    = map(string)
  default = {}
}
