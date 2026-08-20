variable "name" { type = string }
variable "target_resource_id" { type = string }
variable "log_analytics_workspace_id" { type = string }
variable "log_categories" {
  type    = set(string)
  default = []
}
variable "log_category_groups" {
  type    = set(string)
  default = []
}
variable "metric_categories" {
  type    = set(string)
  default = ["AllMetrics"]
}
variable "log_analytics_destination_type" {
  type    = string
  default = null
}
