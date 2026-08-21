variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "subnet_id" { type = string }
variable "sku" { type = string default = "Standard" }
variable "frontend_port" { type = number default = 80 }
variable "backend_port" { type = number default = 80 }
variable "probe_port" { type = number default = 80 }
variable "tags" { type = map(string) default = {} }
