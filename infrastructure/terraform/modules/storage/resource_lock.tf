resource "azurerm_management_lock" "storage" {
  name       = "${var.storage_account_name}-production-protection"
  scope      = azurerm_storage_account.main.id
  lock_level = "CanNotDelete"
  notes      = "Protect production storage account from accidental deletion"
}
