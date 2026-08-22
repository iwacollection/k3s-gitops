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
