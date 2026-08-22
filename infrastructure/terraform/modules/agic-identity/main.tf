resource "azurerm_user_assigned_identity" "this" {
  name                = "${var.name}-identity"
  location            = var.location
  resource_group_name = var.resource_group_name
}

output "principal_id" {
  value = azurerm_user_assigned_identity.this.principal_id
}

output "client_id" {
  value = azurerm_user_assigned_identity.this.client_id
}
