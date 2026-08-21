resource "azurerm_role_assignment" "identity" {
  for_each = {
    for assignment in var.role_assignments :
    "${assignment.scope}-${assignment.role_definition_name}" => assignment
  }

  scope                = each.value.scope
  role_definition_name = each.value.role_definition_name
  principal_id         = azurerm_user_assigned_identity.main.principal_id

  lifecycle {
    prevent_destroy = true
  }
}
