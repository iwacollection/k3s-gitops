variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "replication_type" {
  type = string
  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "GZRS"], var.replication_type)
    error_message = "replication_type must be LRS, ZRS, GRS or GZRS."
  }
}

variable "access_tier" {
  type = string
  validation {
    condition     = contains(["Hot", "Cool"], var.access_tier)
    error_message = "access_tier must be Hot or Cool."
  }
}

variable "public_network_access_enabled" {
  type = bool
}

variable "shared_key_access_enabled" {
  type    = bool
  default = false
  validation {
    condition     = var.shared_key_access_enabled == false
    error_message = "Shared Key access is disabled by the platform standard."
  }
}

variable "blob_versioning_enabled" {
  type    = bool
  default = true
}

variable "delete_retention_days" {
  type    = number
  default = 30
  validation {
    condition     = var.delete_retention_days >= 7 && var.delete_retention_days <= 365
    error_message = "delete_retention_days must be between 7 and 365."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
