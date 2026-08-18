#!/usr/bin/env bash

# Safe local Terraform bootstrap plan for Azure.
# - Uses the current Azure CLI login.
# - Does not create or modify Azure resources.
# - Does not write subscription/tenant IDs into tracked files.
# - Produces one review log and removes the temporary binary plan.

(
  LOG="${1:-azure_terraform_bootstrap_plan.log}"
  ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  TF_DIR="${ROOT_DIR}/enterprise-cicd/terraform/bootstrap"
  PLAN_FILE="${TF_DIR}/bootstrap.tfplan"

  {
    set -euo pipefail

    echo "========================================="
    echo " AZURE TERRAFORM BOOTSTRAP PLAN"
    echo "========================================="

    for cmd in az terraform sha256sum; do
      command -v "$cmd" >/dev/null 2>&1 || {
        echo "ERROR: required command not found: $cmd"
        exit 1
      }
    done

    echo
    echo "[1] Azure account check"
    SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
    SUBSCRIPTION_NAME="$(az account show --query name -o tsv)"
    TENANT_ID="$(az account show --query tenantId -o tsv)"
    ACCOUNT_STATE="$(az account show --query state -o tsv)"

    test -n "$SUBSCRIPTION_ID"
    test "$ACCOUNT_STATE" = "Enabled"

    echo "subscription=${SUBSCRIPTION_NAME}"
    echo "state=${ACCOUNT_STATE}"
    echo "tenant_id=<loaded-from-azure-cli>"
    echo "subscription_id=<loaded-from-azure-cli>"

    echo
    echo "[2] Derive globally unique resource names"
    SUFFIX="$(printf '%s' "$SUBSCRIPTION_ID" | sha256sum | awk '{print substr($1,1,8)}')"

    export TF_VAR_subscription_id="$SUBSCRIPTION_ID"
    export TF_VAR_location="${AZURE_LOCATION:-southeastasia}"
    export TF_VAR_resource_group_name="${AZURE_CICD_RESOURCE_GROUP:-rg-enterprise-cicd-platform}"
    export TF_VAR_acr_name="${AZURE_CICD_ACR_NAME:-acrentcicd${SUFFIX}}"
    export TF_VAR_tfstate_storage_account_name="${AZURE_CICD_TFSTATE_ACCOUNT:-stcicdtf${SUFFIX}}"
    export TF_VAR_tfstate_container_name="${AZURE_CICD_TFSTATE_CONTAINER:-tfstate}"

    echo "location=${TF_VAR_location}"
    echo "resource_group=${TF_VAR_resource_group_name}"
    echo "acr=${TF_VAR_acr_name}"
    echo "tfstate_storage=${TF_VAR_tfstate_storage_account_name}"
    echo "tfstate_container=${TF_VAR_tfstate_container_name}"

    echo
    echo "[3] Azure global-name availability"
    ACR_AVAILABLE="$(az acr check-name --name "$TF_VAR_acr_name" --query nameAvailable -o tsv 2>/dev/null || echo unknown)"
    STORAGE_AVAILABLE="$(az storage account check-name --name "$TF_VAR_tfstate_storage_account_name" --query nameAvailable -o tsv 2>/dev/null || echo unknown)"
    echo "acr_name_available=${ACR_AVAILABLE}"
    echo "storage_name_available=${STORAGE_AVAILABLE}"

    if [ "$ACR_AVAILABLE" = "false" ] || [ "$STORAGE_AVAILABLE" = "false" ]; then
      echo "ERROR: generated Azure resource name is already in use. Override AZURE_CICD_ACR_NAME or AZURE_CICD_TFSTATE_ACCOUNT and retry."
      exit 1
    fi

    echo
    echo "[4] Terraform versions"
    terraform version

    echo
    echo "[5] Terraform format"
    terraform -chdir="$TF_DIR" fmt -check -diff

    echo
    echo "[6] Terraform init (local bootstrap state only)"
    terraform -chdir="$TF_DIR" init -input=false

    echo
    echo "[7] Terraform validate"
    terraform -chdir="$TF_DIR" validate

    echo
    echo "[8] Terraform plan - NO APPLY"
    terraform -chdir="$TF_DIR" plan \
      -input=false \
      -lock=false \
      -out="$PLAN_FILE"

    echo
    echo "[9] Human-readable plan"
    terraform -chdir="$TF_DIR" show -no-color "$PLAN_FILE"

    rm -f "$PLAN_FILE"

    echo
    echo "========================================="
    echo " PLAN SUCCESS - NO AZURE RESOURCE CREATED"
    echo "========================================="

  } 2>&1 | tee "$LOG"

) || {
  STATUS=$?
  echo
  echo "========================================="
  echo " PLAN FAILED"
  echo "========================================="
  echo "exit_code=$STATUS"
  echo "log=${1:-azure_terraform_bootstrap_plan.log}"
  echo "No terraform apply was executed."
  true
}
