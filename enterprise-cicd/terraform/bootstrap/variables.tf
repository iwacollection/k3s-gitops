variable "subscription_id" {
  description = "Azure subscription ID used by the bootstrap stack."
  type        = string
}

variable "location" {
  description = "Primary Azure region for CI/CD platform resources."
  type        = string
  default     = "southeastasia"
}

variable "resource_group_name" {
  description = "Resource group for CI/CD platform bootstrap resources."
  type        = string
  default     = "rg-enterprise-cicd-platform"
}

variable "acr_name" {
  description = "Globally unique Azure Container Registry name."
  type        = string
}

variable "tfstate_storage_account_name" {
  description = "Globally unique Storage Account name for Terraform remote state."
  type        = string
}

variable "tfstate_container_name" {
  description = "Blob container used for Terraform state."
  type        = string
  default     = "tfstate"
}

variable "tags" {
  description = "Common tags applied to resources."
  type        = map(string)
  default = {
    managed-by = "terraform"
    platform   = "enterprise-cicd"
  }
}
