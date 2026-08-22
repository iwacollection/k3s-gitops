variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "sku" {
  type    = string
  default = "Premium"
}

variable "public_network_access_enabled" {
  type    = bool
  default = false
}

variable "geo_replication_locations" {
  description = "Additional Azure regions for ACR geo replication"
  type        = list(string)
  default     = []
}

variable "retention_enabled" {
  description = "Enable ACR retention policy for untagged manifests"
  type        = bool
  default     = true
}

variable "retention_days" {
  description = "Days to retain untagged manifests"
  type        = number
  default     = 30
}

variable "content_trust_enabled" {
  description = "Enable ACR content trust"
  type        = bool
  default     = true
}
