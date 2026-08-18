variable "name" { type = string }
variable "public_ip_name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }

variable "idle_timeout_in_minutes" {
  type    = number
  default = 4
  validation {
    condition     = var.idle_timeout_in_minutes >= 4 && var.idle_timeout_in_minutes <= 120
    error_message = "idle_timeout_in_minutes must be between 4 and 120."
  }
}

variable "zones" {
  type    = list(string)
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
