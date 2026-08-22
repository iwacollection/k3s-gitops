moved {
  from = module.acr_private_endpoint.azurerm_private_dns_zone.this
  to   = module.private_dns.azurerm_private_dns_zone.this["privatelink.azurecr.io"]
}

moved {
  from = module.acr_private_endpoint.azurerm_private_dns_zone_virtual_network_link.this
  to   = module.private_dns.azurerm_private_dns_zone_virtual_network_link.this["privatelink.azurecr.io"]
}

moved {
  from = module.key_vault_private_endpoint.azurerm_private_dns_zone.this
  to   = module.private_dns.azurerm_private_dns_zone.this["privatelink.vaultcore.azure.net"]
}

moved {
  from = module.key_vault_private_endpoint.azurerm_private_dns_zone_virtual_network_link.this
  to   = module.private_dns.azurerm_private_dns_zone_virtual_network_link.this["privatelink.vaultcore.azure.net"]
}

moved {
  from = module.redis_private_endpoint.azurerm_private_dns_zone.this
  to   = module.private_dns.azurerm_private_dns_zone.this["privatelink.redis.cache.windows.net"]
}

moved {
  from = module.redis_private_endpoint.azurerm_private_dns_zone_virtual_network_link.this
  to   = module.private_dns.azurerm_private_dns_zone_virtual_network_link.this["privatelink.redis.cache.windows.net"]
}

moved {
  from = module.postgres_private_endpoint.azurerm_private_dns_zone.this
  to   = module.private_dns.azurerm_private_dns_zone.this["privatelink.postgres.database.azure.com"]
}

moved {
  from = module.postgres_private_endpoint.azurerm_private_dns_zone_virtual_network_link.this
  to   = module.private_dns.azurerm_private_dns_zone_virtual_network_link.this["privatelink.postgres.database.azure.com"]
}
