output "resource_group_name" {
  value       = module.resource_group.name
  description = "Resource group created for the catalog request."
}

output "acr_id" {
  value       = module.acr.id
  description = "ACR resource ID."
}

output "acr_name" {
  value       = module.acr.name
  description = "ACR name."
}

output "login_server" {
  value       = module.acr.login_server
  description = "ACR login server."
}
