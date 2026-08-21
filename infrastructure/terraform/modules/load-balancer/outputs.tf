output "id" {
  description = "Azure Load Balancer resource id"
  value       = azurerm_lb.main.id
}

output "public_ip_id" {
  description = "Azure Load Balancer public IP resource id"
  value       = azurerm_public_ip.main.id
}

output "public_ip_address" {
  description = "Azure Load Balancer public IP address"
  value       = azurerm_public_ip.main.ip_address
}
