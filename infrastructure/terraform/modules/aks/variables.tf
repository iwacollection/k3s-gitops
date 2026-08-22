variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "dns_prefix" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "kubernetes_version" {
  type    = string
  default = null
}

variable "node_count" {
  type    = number
  default = 1
}

variable "vm_size" {
  type    = string
  default = "Standard_D2s_v7"
}

variable "private_cluster_enabled" {
  type    = bool
  default = false
}

variable "service_cidr" {
  type    = string
  default = "10.70.0.0/16"
}

variable "dns_service_ip" {
  type    = string
  default = "10.70.0.10"
}
