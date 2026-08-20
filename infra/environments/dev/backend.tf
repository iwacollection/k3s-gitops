terraform {
  backend "azurerm" {
    resource_group_name  = "rg-platform-cicd"
    storage_account_name = "sttfstatec12c3a3699d8"
    container_name       = "tfstate"
    key                  = "dev/platform.tfstate"
    use_azuread_auth     = true
  }
}
