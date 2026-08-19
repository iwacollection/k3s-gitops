variable "name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }

variable "exposure" {
  type = string
  validation {
    condition     = contains(["public", "internal"], var.exposure)
    error_message = "exposure must be public or internal."
  }
}

variable "subnet_id" {
  type    = string
  default = null
}

variable "frontend_private_ip_address" {
  type    = string
  default = null
}

variable "frontend_port" {
  type = number
  validation {
    condition     = var.frontend_port >= 1 && var.frontend_port <= 65535
    error_message = "frontend_port must be 1..65535."
  }
}

variable "backend_port" {
  type = number
  validation {
    condition     = var.backend_port >= 1 && var.backend_port <= 65535
    error_message = "backend_port must be 1..65535."
  }
}

variable "protocol" {
  type = string
  validation {
    condition     = contains(["Tcp", "Udp", "All"], var.protocol)
    error_message = "protocol must be Tcp, Udp or All."
  }
}

variable "probe_protocol" {
  type = string
  validation {
    condition     = contains(["Tcp", "Http", "Https"], var.probe_protocol)
    error_message = "probe_protocol must be Tcp, Http or Https."
  }
}

variable "probe_port" { type = number }
variable "probe_request_path" {
  type    = string
  default = null
}
variable "idle_timeout_in_minutes" {
  type    = number
  default = 4
}
variable "tags" {
  type    = map(string)
  default = {}
}
