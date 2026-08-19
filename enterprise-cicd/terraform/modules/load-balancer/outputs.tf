output "id" { value = azurerm_lb.this.id }
output "name" { value = azurerm_lb.this.name }
output "backend_address_pool_id" { value = azurerm_lb_backend_address_pool.this.id }
output "frontend_ip_configuration_id" { value = azurerm_lb.this.frontend_ip_configuration[0].id }
output "public_ip_address" { value = var.exposure == "public" ? azurerm_public_ip.this[0].ip_address : null }
output "public_ip_id" { value = var.exposure == "public" ? azurerm_public_ip.this[0].id : null }
