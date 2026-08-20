output "cluster_id" { value = module.aks.id }
output "cluster_name" { value = module.aks.name }
output "oidc_issuer_url" { value = module.aks.oidc_issuer_url }
output "kubelet_identity_object_id" { value = module.aks.kubelet_identity_object_id }
