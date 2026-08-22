output "load_balancer_ip" {
  value = module.load_balancer.public_ip
}

output "redis_hostname" {
  value = module.managed_redis.hostname
}

output "database_fqdn" {
  value = module.database.fqdn
}

output "vnet_id" {
  value = module.network.vnet_id
}

output "nat_gateway_public_ip" {
  value = module.nat_gateway.public_ip
}

output "aks_name" {
  value = module.aks.name
}

output "aks_fqdn" {
  value = module.aks.fqdn
}

output "acr_login_server" {
  value = module.container_registry.login_server
}

output "key_vault_uri" {
  value = module.key_vault.vault_uri
}

output "log_analytics_workspace_id" {
  value = module.monitoring.workspace_id
}

output "workload_identity_client_id" {
  value = azurerm_user_assigned_identity.workload.client_id
}

output "workload_identity_service_account" {
  value = azurerm_federated_identity_credential.workload.subject
}

output "acr_private_ip" {
  value = module.acr_private_endpoint.private_ip_address
}

output "key_vault_private_ip" {
  value = module.key_vault_private_endpoint.private_ip_address
}

output "redis_private_ip" {
  value = module.redis_private_endpoint.private_ip_address
}

output "postgres_private_ip" {
  value = module.postgres_private_endpoint.private_ip_address
}

output "backup_vault_id" {
  value = azurerm_data_protection_backup_vault.production.id
}

output "monitor_action_group_id" {
  value = azurerm_monitor_action_group.platform.id
}
