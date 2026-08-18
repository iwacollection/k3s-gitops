locals {
  enabled_logs = concat(
    [for category in var.log_categories : { category = category, category_group = null }],
    [for group in var.log_category_groups : { category = null, category_group = group }]
  )
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  name                           = var.name
  target_resource_id             = var.target_resource_id
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  log_analytics_destination_type = var.log_analytics_destination_type

  dynamic "enabled_log" {
    for_each = local.enabled_logs
    content {
      category       = enabled_log.value.category
      category_group = enabled_log.value.category_group
    }
  }

  dynamic "enabled_metric" {
    for_each = var.metric_categories
    content {
      category = enabled_metric.value
    }
  }

  lifecycle {
    precondition {
      condition     = length(var.log_categories) + length(var.log_category_groups) + length(var.metric_categories) > 0
      error_message = "At least one log category, log category group or metric category must be enabled."
    }
  }
}
