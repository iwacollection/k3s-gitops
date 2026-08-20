module "role_assignments" {
  source = "../../../modules/role-assignment"

  assignments = var.assignments
}
