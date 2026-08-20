output "log_analytics_workspace_id" { value = azurerm_log_analytics_workspace.this.id }
output "log_analytics_workspace_customer_id" { value = azurerm_log_analytics_workspace.this.workspace_id }
output "monitor_workspace_id" { value = azurerm_monitor_workspace.this.id }
