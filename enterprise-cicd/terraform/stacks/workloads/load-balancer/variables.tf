variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "load_balancer_name" { type = string }
variable "exposure" { type = string }
variable "subnet_id" { type = string, default = null }
variable "frontend_private_ip_address" { type = string, default = null }
variable "frontend_port" { type = number }
variable "backend_port" { type = number }
variable "protocol" { type = string }
variable "probe_protocol" { type = string }
variable "probe_port" { type = number }
variable "probe_request_path" { type = string, default = null }
variable "idle_timeout_in_minutes" { type = number, default = 4 }
variable "tags" { type = map(string), default = {} }
