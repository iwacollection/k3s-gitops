# Subscription quota governance is part of the production IaC control plane.
# The quota identity is intentionally separate from the restricted Terraform
# Apply identity: it can request quota, but Terraform mutations continue to run
# with AZURE_APPLY_CLIENT_ID.

data "azurerm_user_assigned_identity" "quota" {
  name                = "k3s-gitops-iac-plan-dev-uami"
  resource_group_name = "rg-platform-cicd"
}

locals {
  subscription_scope = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
}

resource "azurerm_role_assignment" "quota_request_operator" {
  name                 = uuidv5("url", "${local.subscription_scope}|Quota Request Operator|${data.azurerm_user_assigned_identity.quota.principal_id}")
  scope                = local.subscription_scope
  role_definition_name = "Quota Request Operator"
  principal_id         = data.azurerm_user_assigned_identity.quota.principal_id
}

output "quota_identity_principal_id" {
  description = "Principal ID of the GitHub OIDC identity allowed to request Azure quota increases."
  value       = data.azurerm_user_assigned_identity.quota.principal_id
}

output "quota_request_operator_assignment_id" {
  description = "Subscription-scoped Quota Request Operator RBAC assignment managed by Terraform."
  value       = azurerm_role_assignment.quota_request_operator.id
}
