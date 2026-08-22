resource "azurerm_federated_identity_credential" "agic" {
  name                = "agic-federated-credential"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.this.id

  issuer    = var.oidc_issuer_url
  subject   = var.service_account_subject
  audiences = ["api://AzureADTokenExchange"]
}
