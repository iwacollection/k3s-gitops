variable "name" {
  type        = string
  description = "Globally unique Azure Container Registry name."

  validation {
    condition     = can(regex("^[A-Za-z0-9]{5,50}$", var.name))
    error_message = "ACR name must contain 5-50 alphanumeric characters."
  }
}

variable "resource_group_name" {
  type        = string
  description = "Resource group that owns the registry."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "sku" {
  type        = string
  description = "Approved ACR SKU."
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.sku)
    error_message = "sku must be Standard or Premium."
  }
}

variable "public_network_access_enabled" {
  type        = bool
  description = "Whether the ACR public network endpoint is enabled."
  default     = true
}

variable "retention_days" {
  type        = number
  description = "Untagged manifest retention for Premium registries. Ignored for Standard."
  default     = 30

  validation {
    condition     = var.retention_days >= 7 && var.retention_days <= 365
    error_message = "retention_days must be between 7 and 365."
  }
}

variable "tags" {
  type        = map(string)
  description = "Platform-required Azure tags."
  default     = {}
}
