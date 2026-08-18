resource "azurerm_monitor_data_collection_rule" "container_insights" {
  name                = substr("MSCI-${var.cluster_location}-${var.cluster_name}", 0, 64)
  resource_group_name = var.resource_group_name
  location            = var.cluster_location
  kind                = "Linux"
  tags                = var.tags

  destinations {
    log_analytics {
      workspace_resource_id = var.log_analytics_workspace_id
      name                  = "ciworkspace"
    }
  }

  data_flow {
    streams      = ["Microsoft-ContainerInsights-Group-Default"]
    destinations = ["ciworkspace"]
  }

  data_sources {
    extension {
      streams            = ["Microsoft-ContainerInsights-Group-Default"]
      input_data_sources = []
      extension_name     = "ContainerInsights"
      name               = "ContainerInsightsExtension"
      extension_json = jsonencode({
        dataCollectionSettings = {
          interval               = var.container_collection_interval
          namespaceFilteringMode = var.namespace_filtering_mode
          namespaces             = var.excluded_namespaces
          enableContainerLogV2   = true
        }
      })
    }
  }
}

resource "azurerm_monitor_data_collection_rule_association" "container_insights" {
  name                    = "MSCI-${var.cluster_name}"
  target_resource_id      = var.cluster_id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.container_insights.id
  description             = "Container Insights DCR association managed by the enterprise platform."
}

resource "azurerm_monitor_data_collection_endpoint" "prometheus" {
  name                = substr("MSProm-${var.cluster_location}-${var.cluster_name}", 0, 44)
  resource_group_name = var.resource_group_name
  location            = var.monitor_workspace_location
  kind                = "Linux"
  tags                = var.tags

  lifecycle {
    precondition {
      condition     = lower(var.cluster_location) == lower(var.monitor_workspace_location)
      error_message = "V1 requires AKS and Azure Monitor workspace in the same region."
    }
  }
}

resource "azurerm_monitor_data_collection_rule" "prometheus" {
  name                        = substr("MSProm-${var.cluster_location}-${var.cluster_name}", 0, 64)
  resource_group_name         = var.resource_group_name
  location                    = var.monitor_workspace_location
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.prometheus.id
  kind                        = "Linux"
  tags                        = var.tags

  destinations {
    monitor_account {
      monitor_account_id = var.monitor_workspace_id
      name               = "MonitoringAccount1"
    }
  }

  data_flow {
    streams      = ["Microsoft-PrometheusMetrics"]
    destinations = ["MonitoringAccount1"]
  }

  data_sources {
    prometheus_forwarder {
      streams = ["Microsoft-PrometheusMetrics"]
      name    = "PrometheusDataSource"
    }
  }

  description = "Managed Prometheus DCR for AKS."
}

resource "azurerm_monitor_data_collection_rule_association" "prometheus" {
  name                    = "MSProm-${var.cluster_name}"
  target_resource_id      = var.cluster_id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.prometheus.id
  description             = "Managed Prometheus DCR association managed by the enterprise platform."
}
