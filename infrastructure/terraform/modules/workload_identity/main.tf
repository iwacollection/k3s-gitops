resource "azurerm_user_assigned_identity" "main" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_federated_identity_credential" "github" {
  name                = var.federated_name
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.main.id
  issuer              = var.issuer
  subject             = var.subject
  audience            = ["api://AzureADTokenExchange"]
}
