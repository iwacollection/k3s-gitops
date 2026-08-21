output "id" {
  description = "Azure Cache for Redis resource id"
  value       = azurerm_redis_cache.main.id
}

output "hostname" {
  description = "Azure Cache for Redis hostname"
  value       = azurerm_redis_cache.main.hostname
}
