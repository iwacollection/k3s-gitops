output "id" {
  value = azurerm_private_endpoint.this.id
}

output "private_ip_address" {
  value = azurerm_private_endpoint.this.private_service_connection[0].private_ip_address
}

output "private_dns_zone_id" {
  value = var.private_dns_zone_id
}
