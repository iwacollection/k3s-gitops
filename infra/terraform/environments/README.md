# How to use the Terraform modules (production-ready examples)

1) Initialize
  cd infra/terraform/environments/dev
  terraform init

2) Plan
  terraform plan -var-file=dev.tfvars

3) Apply
  terraform apply -var-file=dev.tfvars

Notes
- The dev/main.tf creates a resource group, an ACR, and an AKS cluster.
- The AKS module will assign the AcrPull role to the cluster kubelet identity if the ACR module is used in the same root (module.acr.acr_resource_id is passed).
- The kubeconfig is exported as a sensitive output. For CI usage prefer `az aks get-credentials` in Azure Pipelines using the Service Connection instead of relying on the output.
- For production readiness review networking (VNet/subnet) requirements and consider providing existing subnet IDs into the AKS module rather than creating default networking in the module.
