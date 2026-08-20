variable "name" {
  description = "User-assigned managed identity name."
  type        = string
}

variable "location" {
  description = "Azure region for the managed identity."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that owns the managed identity."
  type        = string
}

variable "tags" {
  description = "Common tags applied to the managed identity."
  type        = map(string)
  default     = {}
}

variable "federated_credentials" {
  description = "Optional OIDC/WIF federated credentials keyed by logical name."
  type = map(object({
    issuer    = string
    subject   = string
    audiences = optional(list(string), ["api://AzureADTokenExchange"])
  }))
  default = {}
}
