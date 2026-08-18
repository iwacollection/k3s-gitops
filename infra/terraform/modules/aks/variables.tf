variable "resource_group_name" {
  description = "Name of the resource group to create/use for AKS"
  type        = string
}

variable "location" {
  description = "Azure region (eg. eastus)"
  type        = string
}

variable "cluster_name" {
  description = "AKS cluster name"
  type        = string
}

variable "node_count" {
  description = "Default node count for the system node pool"
  type        = number
  default     = 3
}

variable "node_vm_size" {
  description = "VM size for nodes"
  type        = string
  default     = "Standard_DS2_v2"
}

variable "kubernetes_version" {
  description = "Kubernetes version to use (optional)"
  type        = string
  default     = null
}

variable "dns_prefix" {
  description = "DNS prefix for the AKS cluster"
  type        = string
  default     = null
}

variable "network_plugin" {
  description = "CNI plugin: kubenet or azure"
  type        = string
  default     = "azure"
}

variable "service_cidr" {
  description = "Service CIDR for cluster"
  type        = string
  default     = "10.0.0.0/16"
}

variable "dns_service_ip" {
  description = "DNS service IP"
  type        = string
  default     = "10.0.0.10"
}

variable "docker_bridge_cidr" {
  description = "Docker bridge CIDR"
  type        = string
  default     = "172.17.0.1/16"
}

variable "acr_resource_id" {
  description = "(Optional) ACR resource ID to grant pull role to cluster"
  type        = string
  default     = ""
}
