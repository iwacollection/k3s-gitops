variable "cluster_id" { type = string }
variable "cluster_name" { type = string }
variable "cluster_location" { type = string }
variable "resource_group_name" { type = string }
variable "log_analytics_workspace_id" { type = string }
variable "monitor_workspace_id" { type = string }
variable "monitor_workspace_location" { type = string }
variable "container_collection_interval" {
  type    = string
  default = "5m"
}
variable "namespace_filtering_mode" {
  type    = string
  default = "Exclude"
}
variable "excluded_namespaces" {
  type    = list(string)
  default = ["kube-system", "gatekeeper-system"]
}
variable "tags" {
  type    = map(string)
  default = {}
}
