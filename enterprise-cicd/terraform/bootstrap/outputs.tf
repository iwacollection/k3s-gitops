output "resource_group_name" {
  value = azurerm_resource_group.cicd.name
}

output "acr_login_server" {
  value = azurerm_container_registry.cicd.login_server
}

output "tfstate_storage_account_name" {
  value = azurerm_storage_account.tfstate.name
}

output "tfstate_container_name" {
  value = azurerm_storage_container.tfstate.name
}
