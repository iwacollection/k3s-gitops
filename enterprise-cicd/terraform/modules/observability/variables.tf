variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "log_analytics_name" { type = string }
variable "monitor_workspace_name" { type = string }
variable "log_retention_days" { type = number }
variable "daily_quota_gb" { type = number }
variable "internet_ingestion_enabled" { type = bool }
variable "internet_query_enabled" { type = bool }
variable "monitor_public_network_access_enabled" { type = bool }
variable "tags" {
  type    = map(string)
  default = {}
}
