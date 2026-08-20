output "resource_group_name" { value = module.resource_group.name }
output "storage_account_id" { value = module.storage.id }
output "storage_account_name" { value = module.storage.name }
output "primary_blob_endpoint" { value = module.storage.primary_blob_endpoint }
