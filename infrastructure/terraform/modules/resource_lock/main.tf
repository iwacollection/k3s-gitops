terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

variable "resource_id" {
  description = "Azure resource id protected by management lock"
  type        = string
}

variable "lock_name" {
  description = "Management lock name"
  type        = string
  default     = "terraform-production-protection"
}

variable "lock_level" {
  description = "Azure lock level"
  type        = string
  default     = "CanNotDelete"
}

resource "azurerm_management_lock" "production" {
  name       = var.lock_name
  scope      = var.resource_id
  lock_level = var.lock_level
  notes      = "Managed by Terraform production protection module"
}
