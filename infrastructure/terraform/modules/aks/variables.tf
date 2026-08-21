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
  default = 2
}

variable "vm_size" {
  type    = string
  default = "Standard_D2s_v5"
}

variable "private_cluster_enabled" {
  type    = bool
  default = false
}

variable "network_policy" {
  type    = string
  default = "azure"
}
