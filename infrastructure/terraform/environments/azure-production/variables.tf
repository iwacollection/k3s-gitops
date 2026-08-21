variable "name" {
  description = "Environment resource prefix"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastasia"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
}
