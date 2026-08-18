output "resource_group_name" { value = module.resource_group.name }
output "virtual_network_id" { value = module.network.id }
output "subnet_ids" { value = module.network.subnet_ids }
output "private_dns_zone_ids" { value = module.private_dns.zone_ids }
output "nat_gateway_id" { value = try(module.nat_gateway["default"].id, null) }
