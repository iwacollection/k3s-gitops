# IAM Role Binding v1

Self-service Azure RBAC binding for **approved low-risk roles only**. v1 accepts only ServicePrincipal object IDs and resource-group-or-child scopes. Subscription-root, management-group, role-definition and role-assignment scopes are rejected by the renderer.

Normal IaC Apply identities do not receive unrestricted RBAC write. Execution uses a separate constrained IAM OIDC identity.
