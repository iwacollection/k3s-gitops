variable "resource_group_name" {
  type        = string
  description = "Platform-managed resource group name."
}

variable "location" {
  type        = string
  description = "Azure region selected by the request policy."
}

variable "acr_name" {
  type        = string
  description = "Platform-generated globally unique ACR name."
}

variable "sku" {
  type        = string
  description = "Catalog-approved ACR SKU."
}

variable "public_network_access_enabled" {
  type        = bool
  description = "Catalog-approved public network setting."
}

variable "retention_days" {
  type        = number
  description = "Premium untagged manifest retention."
  default     = 30
}

variable "tags" {
  type        = map(string)
  description = "Platform-generated ownership and governance tags."
}
