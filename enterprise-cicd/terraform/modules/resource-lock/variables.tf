variable "name" { type = string }
variable "scope" { type = string }
variable "lock_level" {
  type    = string
  default = "CanNotDelete"

  validation {
    condition     = contains(["CanNotDelete", "ReadOnly"], var.lock_level)
    error_message = "lock_level must be CanNotDelete or ReadOnly."
  }
}
variable "notes" {
  type    = string
  default = "Managed by the enterprise IaC platform."
}
