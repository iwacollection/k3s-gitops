variable "identity_name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "role_assignments" {
  description = "Azure RBAC assignments for the managed identity"
  type = list(object({
    scope                = string
    role_definition_name = string
  }))
  default = []
}
