variable "name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "dns_prefix" { type = string }

variable "kubernetes_version" {
  type    = string
  default = null
}

variable "sku_tier" {
  type    = string
  default = "Standard"
  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.sku_tier)
    error_message = "sku_tier must be Free, Standard or Premium."
  }
}

variable "private_cluster_enabled" {
  type    = bool
  default = true
}

variable "azure_policy_enabled" {
  type    = bool
  default = true
}

variable "automatic_upgrade_channel" {
  type    = string
  default = "stable"
}

variable "node_os_upgrade_channel" {
  type    = string
  default = "NodeImage"
}

variable "admin_group_object_ids" {
  type    = list(string)
  default = []
}

variable "system_node_pool" {
  type = object({
    name                 = optional(string, "system")
    vm_size              = string
    vnet_subnet_id       = string
    node_count           = optional(number, 2)
    auto_scaling_enabled = optional(bool, true)
    min_count            = optional(number, 2)
    max_count            = optional(number, 5)
    zones                = optional(list(string), ["1", "2", "3"])
    max_pods             = optional(number, 50)
    os_disk_size_gb      = optional(number, 128)
  })
}

variable "network_policy" {
  type    = string
  default = "azure"
}

variable "outbound_type" {
  type    = string
  default = "userAssignedNATGateway"
}

variable "service_cidr" {
  type    = string
  default = "10.100.0.0/16"
}

variable "dns_service_ip" {
  type    = string
  default = "10.100.0.10"
}

variable "tags" {
  type    = map(string)
  default = {}
}
