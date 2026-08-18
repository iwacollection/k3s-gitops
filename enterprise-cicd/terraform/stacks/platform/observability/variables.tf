variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "log_analytics_name" { type = string }
variable "monitor_workspace_name" { type = string }
variable "log_retention_days" {
  type    = number
  default = 30
}
variable "daily_quota_gb" {
  type    = number
  default = 5
}
variable "internet_ingestion_enabled" {
  type    = bool
  default = true
}
variable "internet_query_enabled" {
  type    = bool
  default = true
}
variable "monitor_public_network_access_enabled" {
  type    = bool
  default = true
}
variable "tags" {
  type    = map(string)
  default = {}
}
