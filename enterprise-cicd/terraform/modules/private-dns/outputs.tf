output "zone_ids" {
  value = { for key, zone in azurerm_private_dns_zone.this : key => zone.id }
}
