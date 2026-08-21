output "environment" {
  value = var.environment
}

output "location" {
  value = var.location
}

output "resource_prefix" {
  value = var.name
}

output "load_balancer_id" {
  description = "Azure Load Balancer resource id"
  value       = module.load_balancer.id
}

output "postgresql_id" {
  description = "Azure PostgreSQL Flexible Server resource id"
  value       = module.database.id
}

output "redis_id" {
  description = "Azure Cache Redis resource id"
  value       = module.managed_redis.id
}

output "aks_cluster_id" {
  description = "AKS cluster resource id"
  value       = module.aks.id
}

output "acr_id" {
  description = "Azure Container Registry resource id"
  value       = module.container_registry.id
}

output "keyvault_id" {
  description = "Azure Key Vault resource id"
  value       = module.keyvault.id
}
