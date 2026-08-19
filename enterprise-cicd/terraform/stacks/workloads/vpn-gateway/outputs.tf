output "resource_group_name" { value = module.resource_group.name }
output "virtual_network_id" { value = module.network.id }
output "gateway_subnet_id" { value = module.network.subnet_ids["GatewaySubnet"] }
output "vpn_gateway_id" { value = module.vpn_gateway.id }
output "vpn_gateway_name" { value = module.vpn_gateway.name }
output "public_ip_id" { value = module.vpn_gateway.public_ip_id }
output "public_ip_address" { value = module.vpn_gateway.public_ip_address }
