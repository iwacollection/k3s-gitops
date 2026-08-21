resource "azurerm_key_vault" "main" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = "standard"

  soft_delete_retention_days = 90
  purge_protection_enabled   = true

  public_network_access_enabled = false

  enable_rbac_authorization = true

  lifecycle {
    prevent_destroy = true
  }
}
