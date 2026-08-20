variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "cluster_name" { type = string }
variable "dns_prefix" { type = string }
variable "kubernetes_version" {
  type    = string
  default = null
}
variable "aks_subnet_id" { type = string }
variable "acr_id" {
  type    = string
  default = null
}
variable "admin_group_object_ids" {
  type    = list(string)
  default = []
}
variable "private_cluster_enabled" {
  type    = bool
  default = true
}
variable "system_vm_size" {
  type    = string
  default = "Standard_D4s_v5"
}
variable "system_min_count" {
  type    = number
  default = 2
}
variable "system_max_count" {
  type    = number
  default = 5
}
variable "service_cidr" {
  type    = string
  default = "10.100.0.0/16"
}
variable "dns_service_ip" {
  type    = string
  default = "10.100.0.10"
}
variable "outbound_type" {
  type    = string
  default = "userAssignedNATGateway"
}
variable "log_analytics_workspace_id" {
  type    = string
  default = null
}
variable "managed_prometheus_enabled" {
  type    = bool
  default = false
}
variable "prometheus_annotations_allowed" {
  type    = string
  default = ""
}
variable "prometheus_labels_allowed" {
  type    = string
  default = ""
}
variable "tags" {
  type    = map(string)
  default = {}
}
