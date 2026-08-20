terraform {
  backend "azurerm" {
    resource_group_name  = "rg-platform-cicd"
    storage_account_name = "sttfstatec12c3a3699d"
    container_name       = "tfstate"
    key                  = "dev/platform.tfstate"
  }
}
