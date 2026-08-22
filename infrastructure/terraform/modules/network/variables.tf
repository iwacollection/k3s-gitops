variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "address_space" {
  type    = list(string)
  default = ["10.60.0.0/16"]
}

variable "aks_subnet_prefixes" {
  type    = list(string)
  default = ["10.60.0.0/22"]
}

variable "private_endpoint_subnet_prefixes" {
  type    = list(string)
  default = ["10.60.4.0/24"]
}
