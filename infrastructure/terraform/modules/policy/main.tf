terraform {
  required_version = ">= 1.6.0"
}

# Azure Policy module baseline.
# Production policy resources should be instantiated through environment modules.

resource "azurerm_policy_definition" "require_tags" {
  name         = "require-standard-resource-tags"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Require standard resource tags"

  policy_rule = jsonencode({
    if = {
      field  = "tags.environment"
      exists = "false"
    }
    then = {
      effect = "deny"
    }
  })
}

resource "azurerm_policy_definition" "deny_public_aks" {
  name         = "deny-public-aks-api"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Deny public AKS API endpoint"

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.ContainerService/managedClusters"
        },
        {
          field  = "Microsoft.ContainerService/managedClusters/apiServerAccessProfile.enablePrivateCluster"
          equals = false
        }
      ]
    }
    then = {
      effect = "deny"
    }
  })
}
