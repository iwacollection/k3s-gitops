variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "node_count" {
  type    = number
  default = 3
}

variable "vm_size" {
  type    = string
  default = "Standard_D4s_v5"
}

variable "enable_auto_scaling" {
  type    = bool
  default = true
}

variable "min_count" {
  type    = number
  default = 3
}

variable "max_count" {
  type    = number
  default = 10
}

variable "max_surge" {
  type    = string
  default = "33%"
}

variable "availability_zones" {
  type    = list(string)
  default = ["1", "2", "3"]
}

variable "maintenance_window_day" {
  type    = string
  default = "Sunday"
}

variable "maintenance_window_start_time" {
  type    = string
  default = "02:00"
}

variable "maintenance_window_duration" {
  type    = number
  default = 4
}

variable "private_cluster_enabled" {
  type    = bool
  default = true
}

variable "network_policy" {
  type    = string
  default = "azure"
}

variable "azure_rbac_enabled" {
  type    = bool
  default = true
}

variable "workload_identity_enabled" {
  type    = bool
  default = true
}

variable "oidc_issuer_enabled" {
  type    = bool
  default = true
}

variable "enable_workload_node_pool" {
  type    = bool
  default = true
}

variable "workload_vm_size" {
  type    = string
  default = "Standard_D4s_v5"
}

variable "workload_node_count" {
  type    = number
  default = 3
}

variable "workload_min_count" {
  type    = number
  default = 3
}

variable "workload_max_count" {
  type    = number
  default = 20
}
