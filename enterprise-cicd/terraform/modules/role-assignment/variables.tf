variable "assignments" {
  type = map(object({
    scope                = string
    role_definition_name = string
    principal_id         = string
    principal_type       = optional(string)
    description          = optional(string)
  }))
  default = {}
}
