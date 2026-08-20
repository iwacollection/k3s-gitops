variable "resource_id" {
  description = "Azure resource id"
  type        = string
}

variable "lock_name" {
  description = "Lock name"
  type        = string
  default     = "production-resource-lock"
}

variable "lock_level" {
  description = "Lock level CanNotDelete or ReadOnly"
  type        = string
  default     = "CanNotDelete"
}
