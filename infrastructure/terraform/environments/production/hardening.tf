data "azurerm_resource_group" "production" {
  name = var.resource_group_name
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = module.container_registry.id
  role_definition_name = "AcrPull"
  principal_id         = module.aks.kubelet_object_id
}

resource "azurerm_user_assigned_identity" "workload" {
  name                = "k3s-production-workload-identity"
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_federated_identity_credential" "workload" {
  name      = "k3s-production-workload-federation"
  parent_id = azurerm_user_assigned_identity.workload.id
  audience  = ["api://AzureADTokenExchange"]
  issuer    = module.aks.oidc_issuer_url
  subject   = "system:serviceaccount:platform:k3s-workload"
}

resource "azurerm_role_assignment" "workload_key_vault_secrets" {
  scope                = module.key_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.workload.principal_id
}

module "acr_private_endpoint" {
  source = "../../modules/private-endpoint"

  name                           = "k3s-production-acr-pe"
  location                       = var.location
  resource_group_name            = var.resource_group_name
  subnet_id                      = module.network.private_endpoint_subnet_id
  private_connection_resource_id = module.container_registry.id
  subresource_names              = ["registry"]
  private_dns_zone_id            = module.private_dns.zone_ids["privatelink.azurecr.io"]
}

module "key_vault_private_endpoint" {
  source = "../../modules/private-endpoint"

  name                           = "k3s-production-kv-pe"
  location                       = var.location
  resource_group_name            = var.resource_group_name
  subnet_id                      = module.network.private_endpoint_subnet_id
  private_connection_resource_id = module.key_vault.id
  subresource_names              = ["vault"]
  private_dns_zone_id            = module.private_dns.zone_ids["privatelink.vaultcore.azure.net"]
}

module "redis_private_endpoint" {
  source = "../../modules/private-endpoint"

  name                           = "k3s-production-redis-pe"
  location                       = var.location
  resource_group_name            = var.resource_group_name
  subnet_id                      = module.network.private_endpoint_subnet_id
  private_connection_resource_id = module.managed_redis.id
  subresource_names              = ["redisCache"]
  private_dns_zone_id            = module.private_dns.zone_ids["privatelink.redis.cache.windows.net"]
}

module "postgres_private_endpoint" {
  source = "../../modules/private-endpoint"

  name                           = "k3s-production-postgres-pe"
  location                       = var.location
  resource_group_name            = var.resource_group_name
  subnet_id                      = module.network.private_endpoint_subnet_id
  private_connection_resource_id = module.database.id
  subresource_names              = ["postgresqlServer"]
  private_dns_zone_id            = module.private_dns.zone_ids["privatelink.postgres.database.azure.com"]
}

module "diagnostics" {
  source = "../../modules/diagnostic-settings"

  workspace_id = module.monitoring.id
  target_resource_ids = {
    aks           = module.aks.id
    acr           = module.container_registry.id
    key_vault     = module.key_vault.id
    redis         = module.managed_redis.id
    postgres      = module.database.id
    load_balancer = module.load_balancer.id
    vnet          = module.network.vnet_id
  }
}

resource "azurerm_monitor_action_group" "platform" {
  name                = "k3s-production-platform-ag"
  resource_group_name = var.resource_group_name
  short_name          = "k3sprod"
}

resource "azurerm_monitor_activity_log_alert" "administrative_errors" {
  name                = "k3s-production-administrative-errors"
  resource_group_name = var.resource_group_name
  location            = "global"
  scopes              = [data.azurerm_resource_group.production.id]
  description         = "Alert on failed Azure administrative operations in the production resource group."

  criteria {
    category = "Administrative"
    level    = "Error"
  }

  action {
    action_group_id = azurerm_monitor_action_group.platform.id
  }
}

resource "azurerm_data_protection_backup_vault" "production" {
  name                = "k3s-production-backup-vault"
  resource_group_name = var.resource_group_name
  location            = var.location
  datastore_type      = "VaultStore"
  redundancy          = "GeoRedundant"

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_policy_definition" "audit_environment_tag" {
  name         = "k3s-audit-environment-tag"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Audit resources missing environment tag"
  description  = "Audits production resources that do not carry the environment tag required for cost and lifecycle governance."

  policy_rule = jsonencode({
    if = {
      field  = "tags['environment']"
      exists = "false"
    }
    then = {
      effect = "audit"
    }
  })
}

resource "azurerm_resource_group_policy_assignment" "audit_environment_tag" {
  name                 = "k3s-audit-environment-tag"
  resource_group_id    = data.azurerm_resource_group.production.id
  policy_definition_id = azurerm_policy_definition.audit_environment_tag.id
  description          = "Audit missing environment tags in the production resource group."
}

resource "azurerm_security_center_subscription_pricing" "containers" {
  tier          = "Standard"
  resource_type = "Containers"
}

resource "azurerm_security_center_subscription_pricing" "key_vaults" {
  tier          = "Standard"
  resource_type = "KeyVaults"
}

resource "azurerm_consumption_budget_resource_group" "production" {
  name              = "k3s-production-monthly-budget"
  resource_group_id = data.azurerm_resource_group.production.id
  amount            = 1000
  time_grain        = "Monthly"

  time_period {
    start_date = "2026-08-01T00:00:00Z"
    end_date   = "2036-08-01T00:00:00Z"
  }

  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThan"
    threshold_type = "Forecasted"
    contact_groups = [azurerm_monitor_action_group.platform.id]
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_groups = [azurerm_monitor_action_group.platform.id]
  }
}
