output "lock_id" {
  description = "Azure management lock id"
  value       = azurerm_management_lock.production.id
}
