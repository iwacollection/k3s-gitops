variable "resource_group_name" {
  type = string
}

variable "virtual_network_id" {
  type = string
}

variable "private_dns_zones" {
  type = list(string)
  default = [
    "privatelink.azurecr.io",
    "privatelink.vaultcore.azure.net",
    "privatelink.postgres.database.azure.com"
  ]
}

variable "tags" {
  type    = map(string)
  default = {}
}
