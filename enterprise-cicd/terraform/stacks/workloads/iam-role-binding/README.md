# IAM Role Binding Root Stack

Creates only governed Azure RBAC role assignments. The Catalog restricts role names, principal type and scope; the runtime uses a separate constrained IAM Apply identity rather than granting roleAssignment/write to the normal infrastructure Apply identity.
