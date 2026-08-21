output "private_dns_zone_ids" {
  description = "Private DNS zone ids keyed by zone name"
  value = {
    for name, zone in azurerm_private_dns_zone.private : name => zone.id
  }
}

output "acr_private_dns_zone_id" {
  value = try(azurerm_private_dns_zone.private["privatelink.azurecr.io"].id, null)
}

output "keyvault_private_dns_zone_id" {
  value = try(azurerm_private_dns_zone.private["privatelink.vaultcore.azure.net"].id, null)
}

output "postgres_private_dns_zone_id" {
  value = try(azurerm_private_dns_zone.private["privatelink.postgres.database.azure.com"].id, null)
}

output "redis_private_dns_zone_id" {
  value = try(azurerm_private_dns_zone.private["privatelink.redis.cache.windows.net"].id, null)
}
