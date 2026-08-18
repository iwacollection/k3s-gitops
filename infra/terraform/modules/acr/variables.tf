variable "acr_name" {
  description = "ACR name (must be globally unique)"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for ACR"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "sku" {
  description = "ACR SKU"
  type        = string
  default     = "Basic"
}
