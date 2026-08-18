# docs/azure-devops-setup.md

This guide explains how to wire Azure and Azure DevOps to run the pipelines in this repository. It assumes you have Owner/Contributor access to the Azure subscription and Admin access to the Azure DevOps project.

1) Login to Azure

  az login
  az account set --subscription <SUBSCRIPTION_ID>

2) (Optional) Run the helper to create resource group, storage account and ACR

  bash scripts/setup-azure.sh rg-k3s-gitops-dev eastus <tfstate_storage_account_name>

  - The script will create the resource group and storage account container 'tfstate' (if you pass a storage account name).
  - It can optionally create an ACR and will offer to create a Service Principal for you. Save the JSON output if you create the SP.

3) Create Service Principal (if you didn't use the script)

  az ad sp create-for-rbac --name "sp-k3s-gitops" --role Contributor --scopes /subscriptions/<SUB_ID> --sdk-auth

  Save the output JSON. You will need these values to create the Azure DevOps Service Connection or to set pipeline secrets.

4) Create Azure DevOps Service Connection

- Method A (recommended, interactive)
  - Project settings -> Service connections -> New service connection -> Azure Resource Manager -> Service principal (manual)
  - Fill in subscription id, tenant id, client id, client secret. Name it e.g. k3s-gitops-conn.
  - After creation, open the service connection and check "Grant access permission to all pipelines" if you want pipelines to use it by default.

- Method B (az devops CLI)
  - Ensure az devops extension is installed and defaults are set:
    az extension add --name azure-devops
    az devops configure --defaults organization=https://dev.azure.com/<ORG> project=<PROJECT>

  - Run (example):
    bash scripts/create-ado-service-connection.sh k3s-gitops-conn <SUB_ID> "My Subscription" <TENANT_ID> <CLIENT_ID> <CLIENT_SECRET>

5) Create Variable Group (store secrets)

- Method A (UI)
  - Pipelines -> Library -> + Variable group
  - Name: k3s-gitops-vars
  - Add variables (mark secrets as secret): AZURE_CLIENT_SECRET, ACR_PASSWORD (if used), etc.
  - After creating, link the variable group to your pipeline in the pipeline editor.

- Method B (CLI)
  - If you prefer automation, see docs/azure-devops-variable-group.json for a JSON template you can POST to the Azure DevOps REST API using a PAT.

6) Enable the YAML pipeline

- In Azure DevOps: Pipelines -> New pipeline -> GitHub -> select repository -> Configure pipeline
- Point it at .azure-pipelines/azure-pipelines-ci.yml in this repo.
- In pipeline settings, ensure the Service Connection name matches the azureSubscription variable in the YAML (or edit the YAML to match your service connection name).

7) Run and validate

- Create a PR (or push to feature branch) and watch the pipeline run.
- For preview deployments: ensure TF_AKS_RG and TF_AKS_CLUSTER variables point to an AKS cluster with connectivity and that the Service Principal has rights to get credentials (aks get-credentials requires access to the resource group).

8) Cleanup preview on PR close

- The repository contains scripts/cleanup-preview.sh which deletes preview namespaces. To run cleanup automatically on PR close you can either:
  - Create a separate pipeline in Azure DevOps that is triggered via a Service Hook when pull request closed, or
  - Use Azure DevOps REST API / webhooks to call a small Azure Function that runs the cleanup script against the cluster.

Security notes
- Do NOT commit secrets into the repo. Use Azure DevOps Variable Groups or Key Vault-backed secrets.
- Prefer least privilege for the Service Principal; for running Terraform you may need higher privileges for resource creation, but restrict the scope when possible.

