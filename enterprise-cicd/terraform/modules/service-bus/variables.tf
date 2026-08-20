variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "sku" {
  type = string
  validation {
    condition     = contains(["Standard", "Premium"], var.sku)
    error_message = "sku must be Standard or Premium."
  }
}

variable "capacity" {
  type    = number
  default = 1
  validation {
    condition     = contains([1, 2, 4, 8, 16], var.capacity)
    error_message = "Premium capacity must be 1, 2, 4, 8 or 16."
  }
}

variable "public_network_access_enabled" {
  type = bool
}

variable "tags" {
  type    = map(string)
  default = {}
}
