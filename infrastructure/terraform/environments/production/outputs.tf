output "load_balancer_ip" {
  value = module.load_balancer.public_ip
}

output "redis_hostname" {
  value = module.managed_redis.hostname
}

output "database_fqdn" {
  value = module.database.fqdn
}
