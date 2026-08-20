output "container_insights_dcr_id" { value = azurerm_monitor_data_collection_rule.container_insights.id }
output "prometheus_dcr_id" { value = azurerm_monitor_data_collection_rule.prometheus.id }
output "prometheus_dce_id" { value = azurerm_monitor_data_collection_endpoint.prometheus.id }
