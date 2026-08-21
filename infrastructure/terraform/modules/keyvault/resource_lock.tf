resource "azurerm_management_lock" "keyvault" {
  name       = "keyvault-production-protection"
  scope      = azurerm_key_vault.main.id
  lock_level = "CanNotDelete"
  notes      = "Production Key Vault protection managed by Terraform"
}
