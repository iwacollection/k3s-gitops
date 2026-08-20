output "resource_group" {
  description = "Platform identity resource group."
  value = {
    id       = module.resource_group.id
    name     = module.resource_group.name
    location = module.resource_group.location
  }
}

output "identities" {
  description = "Managed identity IDs required by later OIDC/WIF and RBAC wiring."
  value = {
    for key, identity in module.identities : key => {
      id           = identity.id
      client_id    = identity.client_id
      principal_id = identity.principal_id
      tenant_id    = identity.tenant_id
    }
  }
}
