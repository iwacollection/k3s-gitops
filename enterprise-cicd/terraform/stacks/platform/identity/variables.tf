variable "location" {
  description = "Azure region used by the platform identity stack."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that contains CI/CD managed identities."
  type        = string
}

variable "tags" {
  description = "Common platform tags."
  type        = map(string)
  default = {
    managed_by = "terraform"
    domain     = "enterprise-cicd"
  }
}

variable "identity_specs" {
  description = "IaC identities keyed by logical contract name, for example platform-plan, dev-plan or prod-apply."
  type = map(object({
    name = string
    federated_credentials = optional(map(object({
      issuer    = string
      subject   = string
      audiences = optional(list(string), ["api://AzureADTokenExchange"])
    })), {})
  }))

  validation {
    condition     = length(var.identity_specs) > 0
    error_message = "identity_specs must define at least one managed identity."
  }
}
