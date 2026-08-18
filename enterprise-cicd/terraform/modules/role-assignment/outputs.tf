output "ids" {
  value = { for key, assignment in azurerm_role_assignment.this : key => assignment.id }
}
