output "resource_group_name" { value = module.resource_group.name }
output "identity_id" { value = module.managed_identity.id }
output "identity_client_id" { value = module.managed_identity.client_id }
output "identity_principal_id" { value = module.managed_identity.principal_id }
