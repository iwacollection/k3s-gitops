resource "azurerm_nat_gateway" "main" {
 name = var.name
 location = var.location
 resource_group_name = var.resource_group_name
 sku_name = "Standard"
}
output "id" { value = azurerm_nat_gateway.main.id }
