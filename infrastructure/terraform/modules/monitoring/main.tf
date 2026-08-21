terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_days

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_monitor_workspace" "main" {
  name                = "${var.name}-prometheus"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = {
    managed_by = "terraform"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_dashboard_grafana" "main" {
  name                = "${var.name}-grafana"
  resource_group_name = var.resource_group_name
  location            = var.location

  api_key_enabled = false
  deterministic_outbound_ip_enabled = false

  lifecycle {
    prevent_destroy = true
  }
}
