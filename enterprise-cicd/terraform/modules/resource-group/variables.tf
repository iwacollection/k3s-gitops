variable "name" {
  description = "Azure resource group name."
  type        = string
}

variable "location" {
  description = "Azure region for the resource group."
  type        = string
}

variable "tags" {
  description = "Common tags applied to the resource group."
  type        = map(string)
  default     = {}
}
