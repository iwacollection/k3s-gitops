terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

variable "federated_identity_credentials" {
  description = "OIDC federated identity credentials for workload identity"
  type = list(object({
    name                 = string
    issuer               = string
    subject              = string
    audiences            = list(string)
  }))
  default = []
}

resource "azurerm_federated_identity_credential" "workload" {
  for_each = {
    for credential in var.federated_identity_credentials : credential.name => credential
  }

  name                = each.value.name
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.main.id
  issuer              = each.value.issuer
  subject             = each.value.subject
  audiences           = each.value.audiences

  lifecycle {
    prevent_destroy = true
  }
}
