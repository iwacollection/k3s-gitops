output "resource_group_name" { value = module.resource_group.name }
output "load_balancer_id" { value = module.load_balancer.id }
output "load_balancer_name" { value = module.load_balancer.name }
output "backend_address_pool_id" { value = module.load_balancer.backend_address_pool_id }
output "public_ip_id" { value = module.load_balancer.public_ip_id }
output "public_ip_address" { value = module.load_balancer.public_ip_address }
