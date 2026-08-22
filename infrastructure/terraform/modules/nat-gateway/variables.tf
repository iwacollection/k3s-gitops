variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "idle_timeout_in_minutes" {
  type    = number
  default = 10
}
