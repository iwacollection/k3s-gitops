terraform {
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "<TFSTATE_STORAGE_ACCOUNT>" # replace
    container_name       = "tfstate"
    key                  = "k3s-gitops.terraform.tfstate"
  }
}
