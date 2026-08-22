output "public_ip_id" {
  value = azurerm_public_ip.this.id
}

output "gateway_id" {
  value = azurerm_application_gateway.this.id
}
